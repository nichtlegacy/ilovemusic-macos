import Foundation
import Network
import OSLog

@MainActor
protocol DiscordIPCConnectionDelegate: AnyObject {
  func discordIPC(_ client: DiscordIPCClient, didChangeState state: NWConnection.State)
  func discordIPC(_ client: DiscordIPCClient, didReceiveMessage message: String)
  func discordIPCDidClose(_ client: DiscordIPCClient, reason: String)
}

class DiscordIPCClient: @unchecked Sendable {
  /// Discord IPC framing opcodes (little-endian Int32 header: [opcode][length]).
  private enum Opcode: Int32 {
    case handshake = 0
    case frame = 1
    case close = 2
    case ping = 3
    case pong = 4
  }

  /// Sanity bound on a single frame so a garbage length can't make us block forever.
  private static let maxFrameLength: Int32 = 1 << 20  // 1 MiB

  private var connection: NWConnection?
  private let queue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.DiscordIPC", qos: .userInitiated)
  private let logger = Logger(subsystem: "com.nichtlegacy.ILoveMusic", category: "DiscordIPC")

  private var heartbeat: DispatchSourceTimer?
  private var missedPongs = 0
  private var closed = true

  weak var delegate: DiscordIPCConnectionDelegate?

  func connect() {
    disconnect()

    // Find valid socket path
    guard let path = Self.findSocketPath() else {
      logger.error("Could not find Discord IPC socket path.")
      Task { @MainActor in
        self.delegate?.discordIPC(self, didChangeState: .failed(NWError.posix(.ENOENT)))
      }
      return
    }

    logger.info("Attempting connection to \(path)")
    let endpoint = NWEndpoint.unix(path: path)
    let params = NWParameters()
    params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()

    let conn = NWConnection(to: endpoint, using: params)
    self.connection = conn
    self.closed = false
    self.missedPongs = 0

    conn.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      self.logger.info("Connection state changed: \(String(describing: state))")
      switch state {
      case .ready:
        self.startHeartbeat()
      case .failed, .cancelled:
        self.stopHeartbeat()
      default:
        break
      }
      Task { @MainActor in
        self.delegate?.discordIPC(self, didChangeState: state)
      }
    }

    conn.start(queue: queue)
    receiveNext()
  }

  func disconnect() {
    closed = true
    stopHeartbeat()
    connection?.cancel()
    connection = nil
  }

  func send(opcode: Int32, payload: String) {
    guard let connection = connection, connection.state == .ready else { return }
    guard let payloadData = payload.data(using: .utf8) else { return }

    var data = Data()
    var op = opcode
    var len = Int32(payloadData.count)

    data.append(Data(bytes: &op, count: MemoryLayout<Int32>.size))
    data.append(Data(bytes: &len, count: MemoryLayout<Int32>.size))
    data.append(payloadData)

    connection.send(content: data, completion: .contentProcessed { [weak self] error in
      if let error = error {
        self?.logger.error("Send error: \(error)")
      }
    })
  }

  // MARK: - Heartbeat

  /// Discord answers a PING (opcode 3) with a PONG (opcode 4). We ping periodically and,
  /// if two consecutive pings go unanswered, treat the pipe as dead and force a reconnect.
  /// This catches the case where Discord silently stops servicing the socket.
  private func startHeartbeat() {
    stopHeartbeat()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 30, repeating: 30)
    timer.setEventHandler { [weak self] in
      guard let self, let conn = self.connection, conn.state == .ready else { return }
      if self.missedPongs >= 2 {
        self.logger.error("Discord heartbeat timed out; closing connection")
        self.notifyClose(reason: "heartbeat timeout")
        return
      }
      self.missedPongs += 1
      self.send(opcode: Opcode.ping.rawValue, payload: "{}")
    }
    timer.resume()
    heartbeat = timer
  }

  private func stopHeartbeat() {
    heartbeat?.cancel()
    heartbeat = nil
  }

  /// Cancels the socket and tells the delegate exactly once. Idempotent so the heartbeat,
  /// receive loop, and a CLOSE frame can't each trigger a reconnect.
  private func notifyClose(reason: String) {
    guard !closed else { return }
    closed = true
    stopHeartbeat()
    connection?.cancel()
    connection = nil
    logger.info("Connection closed: \(reason)")
    Task { @MainActor in
      self.delegate?.discordIPCDidClose(self, reason: reason)
    }
  }

  // MARK: - Receive

  private func receiveNext() {
    guard let connection = connection else { return }

    connection.receive(minimumIncompleteLength: 8, maximumLength: 8) { [weak self] headerData, _, isComplete, error in
      guard let self = self else { return }
      if let error = error {
        self.logger.error("Receive header error: \(error)")
        self.notifyClose(reason: "receive error: \(error.localizedDescription)")
        return
      }
      if isComplete {
        self.notifyClose(reason: "Discord closed the socket")
        return
      }

      guard let headerData = headerData, headerData.count == 8 else {
        self.notifyClose(reason: "malformed frame header")
        return
      }

      let opcode = headerData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }
      let length = headerData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }

      guard length >= 0, length <= Self.maxFrameLength else {
        self.notifyClose(reason: "invalid frame length \(length)")
        return
      }

      if length == 0 {
        self.handleFrame(opcode: opcode, payload: "")
        self.receiveNext()
        return
      }

      connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payloadData, _, isComplete, error in
        guard let self = self else { return }
        if let error = error {
          self.logger.error("Receive body error: \(error)")
          self.notifyClose(reason: "receive error: \(error.localizedDescription)")
          return
        }
        let message = payloadData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        self.handleFrame(opcode: opcode, payload: message)
        if isComplete {
          self.notifyClose(reason: "Discord closed the socket")
          return
        }
        self.receiveNext()
      }
    }
  }

  private func handleFrame(opcode: Int32, payload: String) {
    // Any inbound traffic proves the pipe is alive.
    missedPongs = 0

    switch Opcode(rawValue: opcode) {
    case .frame, .handshake:
      Task { @MainActor in
        self.delegate?.discordIPC(self, didReceiveMessage: payload)
      }
    case .close:
      logger.info("Discord sent CLOSE: \(payload, privacy: .public)")
      notifyClose(reason: "Discord requested close")
    case .ping:
      // Must echo the payload back as a PONG or Discord will eventually drop us.
      send(opcode: Opcode.pong.rawValue, payload: payload.isEmpty ? "{}" : payload)
    case .pong:
      break
    case nil:
      logger.error("Received unknown opcode \(opcode)")
    }
  }

  static func findSocketPath(
    fileManager: FileManager = .default,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    let tmpVars = ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"]
    var searchPaths = [String]()

    for tmpVar in tmpVars {
      if let val = environment[tmpVar] {
        searchPaths.append(val)
      }
    }
    searchPaths.append("/tmp")
    searchPaths.append("/var/tmp")

    for basePath in searchPaths {
      for socketIndex in 0..<10 {
        let socketName = "discord-ipc-\(socketIndex)"

        let url = URL(fileURLWithPath: basePath).appendingPathComponent(socketName)
        if fileManager.fileExists(atPath: url.path) {
          return url.path
        }

        let snapURL = URL(fileURLWithPath: basePath).appendingPathComponent("snap.discord/\(socketName)")
        if fileManager.fileExists(atPath: snapURL.path) {
          return snapURL.path
        }

        let appURL = URL(fileURLWithPath: basePath).appendingPathComponent("app.com.discordapp.Discord/\(socketName)")
        if fileManager.fileExists(atPath: appURL.path) {
          return appURL.path
        }
      }
    }

    return nil
  }
}

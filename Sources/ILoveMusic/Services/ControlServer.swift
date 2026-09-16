import Foundation
import Network
import os
import Security

/// Lightweight, observable runtime activity for the control server.
///
/// Routine reads (`GET /v1/state`, `/v1/stations`, `/v1/volume`) only update
/// this in-memory status — they no longer write a persistent diagnostic entry.
/// Mutating requests (POST) still go to the persistent diagnostic log.
struct ControlServerRuntimeStatus: Equatable, Sendable {
  var lastRequestAt: Date?
  var lastReadAt: Date?
  var lastReadPath: String?
  var lastMutationAt: Date?
  var lastMutationPath: String?
  var lastErrorAt: Date?

  static let empty = ControlServerRuntimeStatus()
}

/// Local HTTP control server for the Stream Deck plugin (and any other on-device controller).
///
/// Security model:
///   - Binds to 127.0.0.1 only (loopback). Never reachable off the box.
///   - Generates a random 256-bit bearer token at startup; clients must send `Authorization: Bearer <token>`.
///   - Writes `{port, token, version}` to `~/Library/Application Support/ILoveMusic/control.json` with mode 0600.
///   - Validates the `Host:` header to defeat DNS rebinding.
///   - Token is regenerated on every app launch (the file is rewritten).
///
/// All mutable state lives on `queue` (a serial dispatch queue). The `start()` / `stop()` entry
/// points are callable from any actor — they just hop onto the queue.
final class ControlServer: @unchecked Sendable {
  /// Concurrency-safe surface the server calls back into. Implementations are typically `@MainActor`.
  protocol Delegate: AnyObject, Sendable {
    func controlServerSnapshot() async -> ControlSnapshot
    func controlServerStations() async -> [ControlStation]
    func controlServerVolume() async -> ControlVolume
    func controlServerToggle() async
    func controlServerToggleFavorite() async
    func controlServerPlay() async
    func controlServerPause() async
    func controlServerNext() async
    func controlServerRandom(favoritesOnly: Bool) async -> Bool
    func controlServerSelect(stationID: String) async
    func controlServerSetVolume(_ value: Int) async
    func controlServerStepVolume(_ delta: Int) async
    func controlServerSetMuted(_ muted: Bool?) async
  }

  /// Hard caps so a buggy or hostile local client can't exhaust memory or pin
  /// connections. Control payloads are tiny (volume ints, station ids).
  private static let maxBodyLength = 64 * 1024
  private static let connectionTimeout: TimeInterval = 15

  private let logger = Logger(subsystem: "com.nichtlegacy.ILoveMusic", category: "ControlServer")
  private let queue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.control")
  private weak var delegate: (any Delegate)?
  private var listener: NWListener?
  private var token: String = ""
  private var boundPort: UInt16 = 0
  private let handshakePath: URL
  private let diagnosticsStore: ControlDiagnosticsStore?
  private var _runtimeStatus = ControlServerRuntimeStatus()

  /// Invoked on every runtime-status change. Callers must hop to their own
  /// actor before touching shared state.
  var onRuntimeStatusChange: (@Sendable (ControlServerRuntimeStatus) -> Void)?

  init(
    delegate: any Delegate,
    supportDirectoryURL: URL? = nil,
    diagnosticsStore: ControlDiagnosticsStore? = nil
  ) {
    self.delegate = delegate
    self.diagnosticsStore = diagnosticsStore
    let support = supportDirectoryURL ?? AppSupportPaths.supportDirectory()
    try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    self.handshakePath = support.appendingPathComponent("control.json", isDirectory: false)
  }

  func start() {
    queue.async { [weak self] in self?.startOnQueue() }
  }

  func stop() {
    queue.async { [weak self] in self?.stopOnQueue() }
  }

  /// Snapshot of the current in-memory runtime status (last read / mutation /
  /// error). Cheap; reads through the serial queue.
  var runtimeStatus: ControlServerRuntimeStatus {
    queue.sync { _runtimeStatus }
  }

  private func startOnQueue() {
    stopOnQueue()
    self.token = Self.generateToken()

    do {
      let params = NWParameters.tcp
      params.allowLocalEndpointReuse = true
      params.requiredInterfaceType = .loopback
      let listener = try NWListener(using: params, on: .any)
      listener.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        self.queue.async { [weak self] in self?.handleListenerState(state) }
      }
      listener.newConnectionHandler = { [weak self] connection in
        guard let self else { return }
        self.queue.async { [weak self] in self?.handle(connection: connection) }
      }
      listener.start(queue: queue)
      self.listener = listener
    } catch {
      logger.error("control server failed to start: \(error.localizedDescription, privacy: .public)")
      record(area: "Connection", severity: .error, message: "Failed to start server: \(error.localizedDescription)")
    }
  }

  private func stopOnQueue() {
    let hadActiveServer = listener != nil || boundPort != 0 || FileManager.default.fileExists(atPath: handshakePath.path)
    listener?.cancel()
    listener = nil
    boundPort = 0
    try? FileManager.default.removeItem(at: handshakePath)
    if hadActiveServer {
      record(area: "Connection", severity: .info, message: "Server stopped")
    }
  }

  private func handleListenerState(_ state: NWListener.State) {
    switch state {
    case .ready:
      if let p = listener?.port?.rawValue {
        boundPort = p
        writeHandshake(port: p, token: token)
        logger.info("control server listening on 127.0.0.1:\(p, privacy: .public)")
        record(area: "Connection", severity: .info, message: "Listening on 127.0.0.1:\(p)")
      }
    case .failed(let err):
      logger.error("control server failed: \(err.localizedDescription, privacy: .public)")
      try? FileManager.default.removeItem(at: handshakePath)
      record(area: "Connection", severity: .error, message: "Listener failed: \(err.localizedDescription)")
    case .cancelled:
      try? FileManager.default.removeItem(at: handshakePath)
    default:
      break
    }
  }

  private func writeHandshake(port: UInt16, token: String) {
    let payload: [String: Any] = ["port": Int(port), "token": token, "version": 2]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
    do {
      try data.write(to: handshakePath, options: [.atomic])
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: handshakePath.path)
      record(area: "Handshake", severity: .info, message: "Updated control.json for port \(port)")
    } catch {
      logger.error("failed to write handshake file: \(error.localizedDescription, privacy: .public)")
      record(area: "Handshake", severity: .error, message: "Failed to write control.json: \(error.localizedDescription)")
    }
  }

  // MARK: - Connection handling

  private func handle(connection: NWConnection) {
    connection.start(queue: queue)
    // Watchdog: a client that opens a socket but never completes a request would
    // otherwise pin this NWConnection (and its pending receive) forever. Cancel
    // after a grace period; once a response is sent the connection is already
    // cancelled and this is a no-op.
    queue.asyncAfter(deadline: .now() + Self.connectionTimeout) { [weak connection] in
      connection?.cancel()
    }
    receive(connection: connection, accumulated: Data())
  }

  private func receive(connection: NWConnection, accumulated: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
      guard let self else { return }
      if let error {
        self.logger.debug("recv error: \(error.localizedDescription, privacy: .public)")
        self.record(area: "Connection", severity: .warning, message: "Receive error: \(error.localizedDescription)")
        connection.cancel()
        return
      }
      var buffer = accumulated
      if let data { buffer.append(data) }

      // Look for end of headers.
      guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else {
        if isComplete { connection.cancel(); return }
        if buffer.count > 32 * 1024 {
          self.respond(connection, status: 431, body: nil)
          return
        }
        self.receive(connection: connection, accumulated: buffer)
        return
      }

      let headerBytes = buffer.subdata(in: 0..<headerEnd.lowerBound)
      guard let headerString = String(data: headerBytes, encoding: .utf8),
            let request = HTTPRequest.parse(headerString) else {
        self.respond(connection, status: 400, body: nil)
        return
      }

      let bodyStart = headerEnd.upperBound
      let contentLength = request.contentLength
      // Reject malformed (negative — would build a reversed subdata range and
      // crash) or oversized bodies before accumulating them. This runs before
      // auth, so it also caps what an unauthenticated client can buffer.
      guard contentLength >= 0 else {
        self.respond(connection, status: 400, body: nil)
        return
      }
      guard contentLength <= Self.maxBodyLength else {
        self.respond(connection, status: 413, body: nil)
        return
      }
      if buffer.count - bodyStart < contentLength {
        if isComplete { connection.cancel(); return }
        self.receive(connection: connection, accumulated: buffer)
        return
      }
      let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
      self.route(connection: connection, request: request, body: body)
    }
  }

  private func route(connection: NWConnection, request: HTTPRequest, body: Data) {
    // DNS rebinding defense: the Host header must be loopback on our port.
    if let host = request.headers["host"]?.lowercased() {
      let expected = "127.0.0.1:\(boundPort)"
      if host != expected && host != "localhost:\(boundPort)" {
        record(area: "Auth", severity: .warning, message: "Rejected request with invalid host \(host)")
        respond(connection, status: 403, body: nil)
        return
      }
    } else {
      record(area: "Protocol", severity: .warning, message: "Rejected request without Host header")
      respond(connection, status: 400, body: nil)
      return
    }

    // Bearer token (constant-time compare).
    let auth = request.headers["authorization"] ?? ""
    let prefix = "Bearer "
    guard auth.hasPrefix(prefix), Self.constantTimeEqual(String(auth.dropFirst(prefix.count)), token) else {
      record(area: "Auth", severity: .warning, message: "Rejected unauthorized request for \(request.method) \(request.path)")
      respond(connection, status: 401, body: nil)
      return
    }

    let key = "\(request.method) \(request.path)"
    // Routine reads update only the in-memory status; mutations still get
    // a persistent "Request" entry so the diagnostics log captures the
    // interesting events.
    if request.method == "GET" {
      noteRead(path: request.path)
    } else {
      noteMutation(path: request.path)
      record(area: "Request", severity: .info, message: key)
    }
    let connection = connection
    let weakSelf = self
    let weakDelegate = self.delegate
    Task { [weak weakSelf, weak weakDelegate] in
      guard let server = weakSelf, let delegate = weakDelegate else {
        connection.cancel()
        return
      }
      switch key {
      case "GET /v1/state":
        let snap = await delegate.controlServerSnapshot()
        let json = encode(snap)
        server.queue.async { server.respondJSON(connection, json: json) }

      case "GET /v1/stations":
        let stations = await delegate.controlServerStations()
        let json = encode(stations)
        server.queue.async { server.respondJSON(connection, json: json) }

      case "GET /v1/volume":
        let volume = await delegate.controlServerVolume()
        let json = encode(volume)
        server.queue.async { server.respondJSON(connection, json: json) }

      case "POST /v1/toggle":
        await delegate.controlServerToggle()
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/favorite":
        await delegate.controlServerToggleFavorite()
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/play":
        await delegate.controlServerPlay()
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/pause":
        await delegate.controlServerPause()
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/next":
        await delegate.controlServerNext()
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/random":
        let payload = body.isEmpty ? RandomPayload(favoritesOnly: nil) : (try? JSONDecoder().decode(RandomPayload.self, from: body))
        guard let payload else {
          server.record(area: "Protocol", severity: .warning, message: "Invalid payload for POST /v1/random")
          server.queue.async { server.respond(connection, status: 400, body: nil) }
          return
        }
        let didPlay = await delegate.controlServerRandom(favoritesOnly: payload.favoritesOnly ?? false)
        server.queue.async { server.respond(connection, status: didPlay ? 204 : 409, body: nil) }

      case "POST /v1/select":
        let payload = try? JSONDecoder().decode(SelectPayload.self, from: body)
        guard let stationID = payload?.stationId, !stationID.isEmpty else {
          server.record(area: "Protocol", severity: .warning, message: "Invalid payload for POST /v1/select")
          server.queue.async { server.respond(connection, status: 400, body: nil) }
          return
        }
        await delegate.controlServerSelect(stationID: stationID)
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/volume":
        let payload = try? JSONDecoder().decode(SetVolumePayload.self, from: body)
        guard let volume = payload?.volume, (0...100).contains(volume) else {
          server.record(area: "Protocol", severity: .warning, message: "Invalid payload for POST /v1/volume")
          server.queue.async { server.respond(connection, status: 400, body: nil) }
          return
        }
        await delegate.controlServerSetVolume(volume)
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/volume/step":
        let payload = try? JSONDecoder().decode(StepVolumePayload.self, from: body)
        guard let delta = payload?.delta, (-100...100).contains(delta) else {
          server.record(area: "Protocol", severity: .warning, message: "Invalid payload for POST /v1/volume/step")
          server.queue.async { server.respond(connection, status: 400, body: nil) }
          return
        }
        await delegate.controlServerStepVolume(delta)
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      case "POST /v1/mute":
        if body.isEmpty {
          await delegate.controlServerSetMuted(nil)
          server.queue.async { server.respond(connection, status: 204, body: nil) }
          return
        }

        let payload = try? JSONDecoder().decode(MutePayload.self, from: body)
        guard payload != nil else {
          server.record(area: "Protocol", severity: .warning, message: "Invalid payload for POST /v1/mute")
          server.queue.async { server.respond(connection, status: 400, body: nil) }
          return
        }
        await delegate.controlServerSetMuted(payload?.muted)
        server.queue.async { server.respond(connection, status: 204, body: nil) }

      default:
        server.record(area: "Protocol", severity: .warning, message: "Unknown route \(key)")
        server.queue.async { server.respond(connection, status: 404, body: nil) }
      }
    }
  }

  private func record(area: String, severity: ControlLogSeverity, message: String) {
    if severity != .info {
      mutateStatusOnQueue { $0.lastErrorAt = Date() }
    }
    diagnosticsStore?.append(area: area, severity: severity, message: message)
  }

  private func noteRead(path: String) {
    let now = Date()
    mutateStatusOnQueue {
      $0.lastRequestAt = now
      $0.lastReadAt = now
      $0.lastReadPath = path
    }
  }

  private func noteMutation(path: String) {
    let now = Date()
    mutateStatusOnQueue {
      $0.lastRequestAt = now
      $0.lastMutationAt = now
      $0.lastMutationPath = path
    }
  }

  private func mutateStatusOnQueue(_ mutate: (inout ControlServerRuntimeStatus) -> Void) {
    // Must be called from the serial queue.
    mutate(&_runtimeStatus)
    let snapshot = _runtimeStatus
    onRuntimeStatusChange?(snapshot)
  }

  // MARK: - Response helpers

  private func respond(_ connection: NWConnection, status: Int, body: Data?) {
    let reason = HTTPStatus.reason(status)
    var head = "HTTP/1.1 \(status) \(reason)\r\n"
    head += "Connection: close\r\n"
    head += "Cache-Control: no-store\r\n"
    head += "X-Content-Type-Options: nosniff\r\n"
    if let body {
      head += "Content-Length: \(body.count)\r\n\r\n"
    } else {
      head += "Content-Length: 0\r\n\r\n"
    }
    var data = Data(head.utf8)
    if let body { data.append(body) }
    connection.send(content: data, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }

  private func respondJSON(_ connection: NWConnection, json: Data) {
    var head = "HTTP/1.1 200 OK\r\n"
    head += "Connection: close\r\n"
    head += "Content-Type: application/json; charset=utf-8\r\n"
    head += "Cache-Control: no-store\r\n"
    head += "X-Content-Type-Options: nosniff\r\n"
    head += "Content-Length: \(json.count)\r\n\r\n"
    var data = Data(head.utf8)
    data.append(json)
    connection.send(content: data, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }

  // MARK: - Crypto helpers

  private static func generateToken() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    if status != errSecSuccess {
      // Should never happen on macOS; fall back to UUID-derived bytes.
      return UUID().uuidString + UUID().uuidString
    }
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)
    if aBytes.count != bBytes.count { return false }
    var diff: UInt8 = 0
    for i in 0..<aBytes.count { diff |= aBytes[i] ^ bBytes[i] }
    return diff == 0
  }
}

// MARK: - HTTP request parser (minimal HTTP/1.1)

private struct HTTPRequest {
  let method: String
  let path: String
  let headers: [String: String]

  var contentLength: Int { Int(headers["content-length"] ?? "") ?? 0 }

  static func parse(_ raw: String) -> HTTPRequest? {
    let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
    guard let requestLine = lines.first else { return nil }
    let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
    guard parts.count == 3, parts[2].hasPrefix("HTTP/") else { return nil }

    var headers: [String: String] = [:]
    for line in lines.dropFirst() where !line.isEmpty {
      guard let colon = line.firstIndex(of: ":") else { continue }
      let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
      let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      headers[key] = value
    }
    return HTTPRequest(method: parts[0].uppercased(), path: parts[1], headers: headers)
  }
}

private enum HTTPStatus {
  static func reason(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 204: return "No Content"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 409: return "Conflict"
    case 413: return "Payload Too Large"
    case 431: return "Request Header Fields Too Large"
    default: return "Error"
    }
  }
}

// MARK: - Wire types

struct ControlStation: Codable, Sendable {
  let id: String
  let name: String
  let iconURL: String?
}

struct ControlNowPlaying: Codable, Sendable {
  let artist: String?
  let title: String?
  let artworkURL: String?
}

struct ControlSnapshot: Codable, Sendable {
  let phase: String
  let station: ControlStation?
  let nowPlaying: ControlNowPlaying?
  let favorite: Bool
  let volume: Int
  let muted: Bool
}

struct ControlVolume: Codable, Sendable {
  let volume: Int
  let muted: Bool
}

private struct SelectPayload: Decodable {
  let stationId: String
}

private struct SetVolumePayload: Decodable {
  let volume: Int
}

private struct StepVolumePayload: Decodable {
  let delta: Int
}

private struct MutePayload: Decodable {
  let muted: Bool?
}

private struct RandomPayload: Decodable {
  let favoritesOnly: Bool?
}

private func encode<T: Encodable>(_ value: T) -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return (try? encoder.encode(value)) ?? Data("{}".utf8)
}

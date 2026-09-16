import Foundation
import Observation
import Network
import OSLog

@MainActor
@Observable
final class DiscordRichPresenceManager: DiscordIPCConnectionDelegate {
  nonisolated private static let iloveRadioLogoURLString =
    "https://ilovemusic.de/fileadmin/templates/img/iloveradio_icon_sw_400x400.png"

  enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var label: String {
      switch self {
      case .disconnected: return "Disconnected"
      case .connecting: return "Connecting…"
      case .connected: return "Connected"
      case .error: return "Error"
      }
    }
  }

  private(set) var state: ConnectionState = .disconnected
  
  @ObservationIgnored private var clientID: String?
  @ObservationIgnored private let clientFactory: () -> DiscordIPCClient
  @ObservationIgnored private var ipcClient: DiscordIPCClient?
  @ObservationIgnored private var desiredPayload: PresencePayload?
  @ObservationIgnored private let logger = Logger(subsystem: "com.nichtlegacy.ILoveMusic", category: "DiscordManager")
  @ObservationIgnored private var showButton: Bool = true
  @ObservationIgnored private var diagnosticsHandler: ((String, ControlLogSeverity, String) -> Void)?

  @ObservationIgnored private var retryTask: Task<Void, Never>?
  @ObservationIgnored private var pendingClearNonce: String?
  @ObservationIgnored private var disconnectAfterClearTask: Task<Void, Never>?

  /// Discord rate-limits SET_ACTIVITY (~5 updates / 20s) and silently drops the excess.
  /// We coalesce rapid updates: identical payloads are skipped, and a fresh payload sent
  /// sooner than `minUpdateInterval` after the last send is deferred with a trailing flush.
  @ObservationIgnored private var lastSentPayload: PresencePayload?
  @ObservationIgnored private var lastSentAt: Date?
  @ObservationIgnored private var flushTask: Task<Void, Never>?
  @ObservationIgnored private let minUpdateInterval: TimeInterval = 2

  init(clientFactory: @escaping () -> DiscordIPCClient = { DiscordIPCClient() }) {
    self.clientFactory = clientFactory
  }

  func configure(clientID: String?, showButton: Bool = true) {
    self.clientID = clientID?.trimmingCharacters(in: .whitespaces).nilIfEmpty
    self.showButton = showButton
  }

  func configureDiagnostics(
    _ handler: @escaping (String, ControlLogSeverity, String) -> Void
  ) {
    diagnosticsHandler = handler
  }

  func start() {
    guard let clientID, !clientID.isEmpty else {
      state = .error("Missing Discord application client ID")
      record("Lifecycle", severity: .error, "start aborted: missing application ID")
      return
    }
    
    // Don't restart if already connected or connecting
    let shouldStart: Bool
    switch state {
    case .disconnected, .error: shouldStart = true
    default: shouldStart = false
    }
    guard shouldStart else { return }
    
    state = .connecting
    record("Lifecycle", "start requested")
    
    let client = clientFactory()
    client.delegate = self
    self.ipcClient = client
    client.connect()
    
    startRetryTimer()
  }

  func stop() {
    retryTask?.cancel()
    retryTask = nil
    desiredPayload = nil
    record("Lifecycle", "stop requested")

    guard let client = ipcClient else {
      state = .disconnected
      return
    }

    guard state == .connected, let nonce = sendClearActivity(using: client) else {
      performDisconnect()
      return
    }

    pendingClearNonce = nonce
    scheduleDisconnectAfterClearAck(expectedNonce: nonce)
  }
  
  private func startRetryTimer() {
    retryTask?.cancel()
    retryTask = Task { [weak self] in
      while let self, !Task.isCancelled {
        try? await Task.sleep(for: .seconds(15))
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
          if case .error = self.state {
            self.logger.info("Retrying Discord connection...")
            self.start()
          } else if self.state == .disconnected {
            self.logger.info("Retrying Discord connection...")
            self.start()
          }
        }
      }
    }
  }

  struct PresencePayload: Equatable {
    var stationName: String?
    var artist: String?
    var title: String?
    var artworkURL: URL?
    var listenerCount: Int?
    var startedAt: Date?
    var websiteURL: URL?
    var showStationLogo = true
  }

  func update(_ payload: PresencePayload) {
    desiredPayload = payload
    record("Presence", "queued update: \(presenceSummary(payload))")
    scheduleFlush()
  }

  /// Sends the desired payload while respecting dedupe + rate limiting.
  private func scheduleFlush() {
    guard state == .connected, ipcClient != nil else { return }
    guard let payload = desiredPayload else { return }

    // Nothing changed since the last send — don't burn a rate-limit slot.
    if lastSentPayload == payload { return }

    if let lastSentAt {
      let elapsed = Date().timeIntervalSince(lastSentAt)
      if elapsed < minUpdateInterval {
        // Already waiting; the pending flush will pick up the newest desiredPayload.
        guard flushTask == nil else { return }
        let wait = minUpdateInterval - elapsed
        flushTask = Task { [weak self] in
          try? await Task.sleep(for: .seconds(wait))
          guard let self, !Task.isCancelled else { return }
          self.flushTask = nil
          self.scheduleFlush()
        }
        return
      }
    }

    performSend(payload)
  }

  private func performSend(_ payload: PresencePayload) {
    flushTask?.cancel()
    flushTask = nil
    lastSentPayload = payload
    lastSentAt = Date()
    sendActivity(payload)
  }
  
  private func sendActivity(_ payload: PresencePayload) {
    guard state == .connected, let ipcClient else { return }
    do {
      let command = try Self.makeSetActivityCommand(
        payload: payload,
        showButton: showButton,
        processID: ProcessInfo.processInfo.processIdentifier
      )
      ipcClient.send(opcode: 1, payload: command.jsonString)
    } catch {
      logger.error("Failed to serialize activity payload: \(error)")
    }
  }

  func clear() {
    desiredPayload = nil
    lastSentPayload = nil
    flushTask?.cancel()
    flushTask = nil
    record("Presence", "clear requested")
    guard state == .connected, let ipcClient else {
      record("Presence", severity: .warning, "clear queued until next Discord READY")
      return
    }

    _ = sendClearActivity(using: ipcClient)
  }

  // MARK: - DiscordIPCConnectionDelegate
  
  nonisolated func discordIPC(_ client: DiscordIPCClient, didChangeState state: NWConnection.State) {
    Task { @MainActor in
      switch state {
      case .ready:
        self.record("Connection", "socket ready; sending handshake")
        // Connection ready, send Handshake (opcode 0)
        if let clientID = self.clientID {
          let handshake = "{\"v\": 1, \"client_id\": \"\(clientID)\"}"
          client.send(opcode: 0, payload: handshake)
        }
      case .failed(let error), .waiting(let error):
        self.state = .error("Connection failed: \(error.localizedDescription)")
        self.record("Connection", severity: .error, "socket failure: \(error.localizedDescription)")
      case .cancelled:
        if self.state != .error("Missing Discord application client ID") {
          self.state = .disconnected
        }
        self.record("Connection", "socket cancelled")
      default:
        break
      }
    }
  }
  
  nonisolated func discordIPC(_ client: DiscordIPCClient, didReceiveMessage message: String) {
    Task { @MainActor in
      // Try to parse the response
      guard let data = message.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return
      }
      
      // Check for handshake success
      if let evt = json["evt"] as? String, evt == "READY" {
        self.state = .connected
        self.record("Connection", "Discord READY received")
        self.syncDesiredActivity()
        return
      }

      if let cmd = json["cmd"] as? String,
         cmd == "SET_ACTIVITY",
         let nonce = json["nonce"] as? String,
         nonce == self.pendingClearNonce {
        self.pendingClearNonce = nil
        self.record("Presence", "clear acknowledged; disconnecting")
        self.performDisconnect()
        return
      }
      
      // Check for errors
      if let evt = json["evt"] as? String, evt == "ERROR", let data = json["data"] as? [String: Any], let msg = data["message"] as? String {
        if let nonce = json["nonce"] as? String, nonce == self.pendingClearNonce {
          self.pendingClearNonce = nil
          self.record("Presence", severity: .warning, "clear failed but disconnecting anyway: \(msg)")
          self.performDisconnect()
          return
        }
        self.state = .error("Discord Error: \(msg)")
        self.record("Connection", severity: .error, "Discord error: \(msg)")
      }
    }
  }

  nonisolated func discordIPCDidClose(_ client: DiscordIPCClient, reason: String) {
    Task { @MainActor in
      // Ignore close notices from a stale client we've already replaced.
      guard client === self.ipcClient else { return }

      self.ipcClient = nil
      self.flushTask?.cancel()
      self.flushTask = nil
      self.lastSentPayload = nil
      self.lastSentAt = nil
      self.pendingClearNonce = nil
      self.disconnectAfterClearTask?.cancel()
      self.disconnectAfterClearTask = nil

      if self.state != .error("Missing Discord application client ID") {
        self.state = .disconnected
      }
      self.record("Connection", severity: .warning, "Discord closed connection: \(reason); reconnecting")

      // desiredPayload is intentionally retained so the activity resyncs on the next READY.
      self.start()
    }
  }

  private func sendClearActivity(using ipcClient: DiscordIPCClient) -> String? {
    do {
      let command = try Self.makeClearActivityCommand(processID: ProcessInfo.processInfo.processIdentifier)
      ipcClient.send(opcode: 1, payload: command.jsonString)
      record("Presence", "sent clear activity")
      return command.nonce
    } catch {
      logger.error("Failed to serialize clear activity payload: \(error)")
      record("Presence", severity: .error, "failed to serialize clear payload: \(error.localizedDescription)")
      return nil
    }
  }

  private func scheduleDisconnectAfterClearAck(expectedNonce: String) {
    disconnectAfterClearTask?.cancel()
    disconnectAfterClearTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard let self else { return }
      guard !Task.isCancelled else { return }

      await MainActor.run {
        guard self.pendingClearNonce == expectedNonce else { return }
        self.pendingClearNonce = nil
        self.performDisconnect()
      }
    }
  }

  private func performDisconnect() {
    disconnectAfterClearTask?.cancel()
    disconnectAfterClearTask = nil
    pendingClearNonce = nil
    flushTask?.cancel()
    flushTask = nil
    lastSentPayload = nil
    lastSentAt = nil
    record("Lifecycle", "disconnecting IPC client")

    if let client = ipcClient {
      client.send(opcode: 2, payload: "{}")
      client.disconnect()
      ipcClient = nil
    }

    state = .disconnected
  }

  private func syncDesiredActivity() {
    guard state == .connected, let ipcClient else { return }
    if let desiredPayload {
      // Fresh connection: send immediately, bypassing the rate-limit window.
      performSend(desiredPayload)
    } else {
      lastSentPayload = nil
      _ = sendClearActivity(using: ipcClient)
    }
  }

  private func record(
    _ area: String,
    severity: ControlLogSeverity = .info,
    _ message: String
  ) {
    switch severity {
    case .info:
      logger.info("\(area, privacy: .public): \(message, privacy: .public)")
    case .warning:
      logger.warning("\(area, privacy: .public): \(message, privacy: .public)")
    case .error:
      logger.error("\(area, privacy: .public): \(message, privacy: .public)")
    }
    diagnosticsHandler?(area, severity, message)
  }

  private func presenceSummary(_ payload: PresencePayload) -> String {
    let station = payload.stationName?.nilIfEmpty ?? "unknown station"
    let title = payload.title?.nilIfEmpty
    let artist = payload.artist?.nilIfEmpty

    if let title, let artist {
      return "\(station) | \(artist) - \(title)"
    }
    if let title {
      return "\(station) | \(title)"
    }
    if let artist {
      return "\(station) | \(artist)"
    }
    return station
  }

  nonisolated static func makeSetActivityCommand(
    payload: PresencePayload,
    showButton: Bool,
    processID: Int32,
    nonce: String = UUID().uuidString
  ) throws -> (nonce: String, jsonString: String) {
    var activity: [String: Any] = [:]
    activity["type"] = 2
    let stationLine = stationLine(from: payload)
    let stationHoverText = payload.stationName?.nilIfEmpty ?? AppIdentity.displayName

    if let title = payload.title, !title.isEmpty, let artist = payload.artist, !artist.isEmpty {
      activity["details"] = title
      activity["state"] = artist
    } else if let title = payload.title, !title.isEmpty {
      activity["details"] = title
      activity["state"] = stationLine ?? "Playing"
    } else if let artist = payload.artist, !artist.isEmpty {
      activity["details"] = artist
      activity["state"] = stationLine ?? "Playing"
    } else {
      activity["details"] = stationLine ?? "Playing"
    }

    var assets: [String: String] = [:]
    if let artworkURL = payload.artworkURL {
      assets["large_image"] = artworkURL.absoluteString
      assets["large_text"] = stationHoverText
    } else {
      assets["large_image"] = "ilovemusic_logo"
      assets["large_text"] = stationHoverText
    }
    if payload.showStationLogo {
      assets["small_image"] = iloveRadioLogoURLString
      assets["small_text"] = stationHoverText
    }

    if !assets.isEmpty {
      activity["assets"] = assets
    }

    if let startedAt = payload.startedAt {
      activity["timestamps"] = [
        "start": Int(startedAt.timeIntervalSince1970)
      ]
    }

    if showButton, let websiteURL = payload.websiteURL {
      let urlString = websiteURL.absoluteString
      activity["details_url"] = urlString
      activity["state_url"] = urlString
      assets["large_url"] = urlString
      if payload.showStationLogo {
        assets["small_url"] = urlString
      }
      activity["assets"] = assets

      let rawLabel = "Listen to \(payload.stationName ?? AppIdentity.displayName)"
      let label = String(rawLabel.prefix(32))
      activity["buttons"] = [
        [
          "label": label,
          "url": urlString
        ]
      ]
    }

    let args: [String: Any] = [
      "pid": processID,
      "activity": activity
    ]
    let command: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": args,
      "nonce": nonce
    ]
    let data = try JSONSerialization.data(withJSONObject: command, options: [])
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw DiscordRPCSerializationError.invalidUTF8
    }
    return (nonce, jsonString)
  }

  nonisolated static func makeClearActivityCommand(
    processID: Int32,
    nonce: String = UUID().uuidString
  ) throws -> (nonce: String, jsonString: String) {
    let args: [String: Any] = [
      "pid": processID,
      "activity": NSNull()
    ]
    let command: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": args,
      "nonce": nonce
    ]
    let data = try JSONSerialization.data(withJSONObject: command, options: [])
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw DiscordRPCSerializationError.invalidUTF8
    }
    return (nonce, jsonString)
  }
}

enum DiscordRPCSerializationError: Error {
  case invalidUTF8
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension DiscordRichPresenceManager {
  nonisolated static func stationLine(from payload: PresencePayload) -> String? {
    let stationName = payload.stationName?.nilIfEmpty
    guard let stationName else { return nil }

    guard let listenerCount = payload.listenerCount, listenerCount > 0 else {
      return stationName
    }

    let formattedCount = NumberFormatter.localizedString(
      from: NSNumber(value: listenerCount),
      number: .decimal
    )
    let suffix = listenerCount == 1 ? "listener" : "listeners"
    return "\(stationName) • \(formattedCount) \(suffix)"
  }
}

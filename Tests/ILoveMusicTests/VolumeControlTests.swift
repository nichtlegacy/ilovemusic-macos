import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Test
func playbackControllerStepVolumeRespectsMuteRules() {
  let controller = PlaybackController()

  controller.restoreVolume(volume: 0.40, muted: true)
  controller.stepVolume(by: 5)
  #expect(controller.volumePercent == 45)
  #expect(controller.isMuted == false)

  controller.restoreVolume(volume: 0.40, muted: true)
  controller.stepVolume(by: -5)
  #expect(controller.volumePercent == 35)
  #expect(controller.isMuted == true)
}

@Test
func controlServerStateAndVolumeEndpointsExposeCurrentValues() async throws {
  let harness = try await makeControlServerHarness(volume: 42, muted: false, favorite: true)
  defer { harness.stop() }

  let state = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/state"
  )
  #expect(state.status == 200)
  #expect(state.json["favorite"] as? Bool == true)
  #expect(state.json["volume"] as? Int == 42)
  #expect(state.json["muted"] as? Bool == false)
  #expect(state.json["phase"] as? String == "idle")

  let volume = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/volume"
  )
  #expect(volume.status == 200)
  #expect(volume.json["volume"] as? Int == 42)
  #expect(volume.json["muted"] as? Bool == false)
}

@Test
func controlServerStateAlwaysIncludesVolumeAndMutedContract() async throws {
  // Stream Deck plugin treats /v1/state as the canonical source for volume +
  // muted. Regressing those fields out of the snapshot would flip the plugin
  // onto a per-action /v1/volume fallback and re-introduce N+1 polling — keep
  // this contract pinned so changes to the Swift snapshot have to opt in.
  for (volume, muted) in [(0, true), (50, false), (100, true)] {
    let harness = try await makeControlServerHarness(volume: volume, muted: muted)
    defer { harness.stop() }

    let json = try await requestJSON(
      port: harness.handshake.port,
      token: harness.handshake.token,
      method: "GET",
      path: "/v1/state"
    )
    #expect(json.status == 200)
    #expect(json.json["volume"] is Int)
    #expect(json.json["muted"] is Bool)
    #expect(json.json["volume"] as? Int == volume)
    #expect(json.json["muted"] as? Bool == muted)

    // The wire decoder matches the plugin contract: both fields are present
    // and decoded into the strict Codable struct without optionality.
    let raw = try await requestRaw(
      port: harness.handshake.port,
      token: harness.handshake.token,
      method: "GET",
      path: "/v1/state"
    )
    let payload = try JSONDecoder().decode(ControlSnapshot.self, from: raw.body)
    #expect(payload.volume == volume)
    #expect(payload.muted == muted)
  }
}

@Test
func controlServerVolumeMutationsHandleStepAndMuteFlow() async throws {
  let harness = try await makeControlServerHarness(volume: 40, muted: false)
  defer { harness.stop() }

  let setVolume = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/volume",
    body: #"{"volume":40}"#
  )
  #expect(setVolume.status == 204)

  let mute = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/mute"
  )
  #expect(mute.status == 204)

  let step = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/volume/step",
    body: #"{"delta":5}"#
  )
  #expect(step.status == 204)

  let volume = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/volume"
  )
  #expect(volume.json["volume"] as? Int == 45)
  #expect(volume.json["muted"] as? Bool == false)

  let explicitMute = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/mute",
    body: #"{"muted":true}"#
  )
  #expect(explicitMute.status == 204)

  let afterMute = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/volume"
  )
  #expect(afterMute.json["volume"] as? Int == 45)
  #expect(afterMute.json["muted"] as? Bool == true)
}

@Test
func controlServerFavoriteMutationTracksCurrentChannel() async throws {
  let harness = try await makeControlServerHarness(volume: 42, muted: false, favorite: false)
  defer { harness.stop() }

  let initialState = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/state"
  )
  #expect(initialState.json["favorite"] as? Bool == false)

  let toggleFavorite = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/favorite"
  )
  #expect(toggleFavorite.status == 204)

  let favoritedState = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/state"
  )
  #expect(favoritedState.json["favorite"] as? Bool == true)

  let unfavorite = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/favorite"
  )
  #expect(unfavorite.status == 204)

  let unfavoritedState = try await requestJSON(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/state"
  )
  #expect(unfavoritedState.json["favorite"] as? Bool == false)
}

@Test
func controlServerRandomEndpointSupportsFavoritesOnlyMode() async throws {
  let harness = try await makeControlServerHarness(volume: 42, muted: false)
  defer { harness.stop() }

  let allChannels = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/random"
  )
  #expect(allChannels.status == 204)
  #expect(await harness.delegate.lastRandomFavoritesOnly == false)

  let favoritesOnly = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/random",
    body: #"{"favoritesOnly":true}"#
  )
  #expect(favoritesOnly.status == 204)
  #expect(await harness.delegate.lastRandomFavoritesOnly == true)
}

@Test
func controlServerRejectsInvalidPayloadsAndUnauthorizedRequests() async throws {
  let harness = try await makeControlServerHarness(volume: 42, muted: false)
  defer { harness.stop() }

  let missingAuth = try await requestRaw(
    port: harness.handshake.port,
    token: nil,
    method: "GET",
    path: "/v1/volume"
  )
  #expect(missingAuth.status == 401)

  let wrongHost = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "GET",
    path: "/v1/volume",
    host: "evil.test:\(harness.handshake.port)"
  )
  #expect(wrongHost.status == 403)

  let invalidAbsolute = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/volume",
    body: #"{"volume":101}"#
  )
  #expect(invalidAbsolute.status == 400)

  let invalidAbsoluteType = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/volume",
    body: #"{"volume":"abc"}"#
  )
  #expect(invalidAbsoluteType.status == 400)

  let invalidStep = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/volume/step",
    body: #"{"delta":-101}"#
  )
  #expect(invalidStep.status == 400)

  let invalidMute = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/mute",
    body: #"{"muted":"abc"}"#
  )
  #expect(invalidMute.status == 400)

  let invalidRandom = try await requestRaw(
    port: harness.handshake.port,
    token: harness.handshake.token,
    method: "POST",
    path: "/v1/random",
    body: #"{"favoritesOnly":"abc"}"#
  )
  #expect(invalidRandom.status == 400)
}

@Test
func controlServerWritesConnectionDiagnostics() async throws {
  let supportDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

  let diagnosticsStore = ControlDiagnosticsStore(
    supportDirectoryURL: supportDirectory,
    maxEntries: 20,
    flushDebounce: .milliseconds(0)
  )
  let delegate = TestControlDelegate(volume: 42, muted: false, favorite: false)
  let server = ControlServer(
    delegate: delegate,
    supportDirectoryURL: supportDirectory,
    diagnosticsStore: diagnosticsStore
  )
  server.start()
  defer { server.stop() }

  let handshake = try await waitForHandshake(at: supportDirectory.appendingPathComponent("control.json"))

  // Routine GETs no longer produce persistent "Request" diagnostics.
  let success = try await requestRaw(
    port: handshake.port,
    token: handshake.token,
    method: "GET",
    path: "/v1/state"
  )
  #expect(success.status == 200)

  // A mutating POST should still persist a "Request" entry.
  let mutation = try await requestRaw(
    port: handshake.port,
    token: handshake.token,
    method: "POST",
    path: "/v1/toggle"
  )
  #expect(mutation.status == 204)

  // Auth failures continue to be logged persistently.
  let unauthorized = try await requestRaw(
    port: handshake.port,
    token: nil,
    method: "GET",
    path: "/v1/volume"
  )
  #expect(unauthorized.status == 401)

  diagnosticsStore.flush()
  let entries = diagnosticsStore.load()
  #expect(entries.contains(where: { $0.area == "Handshake" && $0.message.contains("control.json") }))
  #expect(entries.contains(where: { $0.area == "Request" && $0.message == "POST /v1/toggle" }))
  #expect(!entries.contains(where: { $0.area == "Request" && $0.message == "GET /v1/state" }))
  #expect(entries.contains(where: { $0.area == "Auth" && $0.severity == .warning }))

  // Routine read still updates the in-memory runtime status.
  let status = server.runtimeStatus
  #expect(status.lastReadAt != nil)
  #expect(status.lastReadPath == "/v1/state")
  #expect(status.lastMutationPath == "/v1/toggle")
}

private struct ControlServerHarness {
  let server: ControlServer
  let delegate: TestControlDelegate
  let handshake: TestHandshake

  func stop() {
    server.stop()
  }
}

private struct TestHandshake: Decodable {
  let port: Int
  let token: String
  let version: Int
}

private struct TestHTTPResponse {
  let status: Int
  let body: Data
}

private actor TestControlDelegate: ControlServer.Delegate {
  private var volume: Int
  private var muted: Bool
  private var favorite: Bool
  private(set) var lastRandomFavoritesOnly: Bool?

  init(volume: Int, muted: Bool, favorite: Bool) {
    self.volume = volume
    self.muted = muted
    self.favorite = favorite
  }

  func controlServerSnapshot() async -> ControlSnapshot {
    ControlSnapshot(
      phase: "idle",
      station: nil,
      nowPlaying: nil,
      favorite: favorite,
      volume: volume,
      muted: muted
    )
  }

  func controlServerStations() async -> [ControlStation] {
    []
  }

  func controlServerVolume() async -> ControlVolume {
    ControlVolume(volume: volume, muted: muted)
  }

  func controlServerToggle() async {}
  func controlServerToggleFavorite() async { favorite.toggle() }
  func controlServerPlay() async {}
  func controlServerPause() async {}
  func controlServerNext() async {}
  func controlServerRandom(favoritesOnly: Bool) async -> Bool {
    lastRandomFavoritesOnly = favoritesOnly
    return true
  }
  func controlServerSelect(stationID: String) async {}

  func controlServerSetVolume(_ value: Int) async {
    volume = min(max(value, 0), 100)
    if volume > 0 {
      muted = false
    }
  }

  func controlServerStepVolume(_ delta: Int) async {
    volume = min(max(volume + delta, 0), 100)
    if delta > 0 && muted {
      muted = false
    }
  }

  func controlServerSetMuted(_ muted: Bool?) async {
    if let muted {
      self.muted = muted
    } else {
      self.muted.toggle()
    }
  }
}

private func makeControlServerHarness(
  volume: Int,
  muted: Bool,
  favorite: Bool = false
) async throws -> ControlServerHarness {
  let supportDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

  let delegate = TestControlDelegate(volume: volume, muted: muted, favorite: favorite)
  let server = ControlServer(delegate: delegate, supportDirectoryURL: supportDirectory)
  server.start()

  let handshake = try await waitForHandshake(at: supportDirectory.appendingPathComponent("control.json"))
  #expect(handshake.version == 2)
  return ControlServerHarness(server: server, delegate: delegate, handshake: handshake)
}

private func waitForHandshake(at url: URL) async throws -> TestHandshake {
  for _ in 0..<80 {
    if let data = try? Data(contentsOf: url),
       let handshake = try? JSONDecoder().decode(TestHandshake.self, from: data) {
      return handshake
    }
    try await Task.sleep(for: .milliseconds(50))
  }

  throw NSError(domain: "VolumeControlTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Handshake file never appeared"])
}

private func requestJSON(
  port: Int,
  token: String?,
  method: String,
  path: String,
  host: String? = nil,
  body: String? = nil
) async throws -> (status: Int, json: [String: Any]) {
  let response = try await requestRaw(
    port: port,
    token: token,
    method: method,
    path: path,
    host: host,
    body: body
  )
  let json = try XCTJSON(response.body)
  return (response.status, json)
}

/// Ceiling for a loopback round-trip against the control server.
///
/// This guards against a hung server; it is not a latency assertion, so it is
/// deliberately generous. It has to stay below `ControlServer.connectionTimeout`
/// times two, otherwise a genuinely stuck request would be reported as the
/// server's watchdog closing the socket rather than as a client timeout.
private let controlServerRequestTimeoutSeconds = 30

private func requestRaw(
  port: Int,
  token: String?,
  method: String,
  path: String,
  host: String? = nil,
  body: String? = nil
) async throws -> TestHTTPResponse {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")

  var arguments = [
    "-i",
    "-sS",
    "--max-time", "\(controlServerRequestTimeoutSeconds)",
    "-X", method,
    "-H", "Host: \(host ?? "127.0.0.1:\(port)")",
    "http://127.0.0.1:\(port)\(path)",
  ]
  if let token {
    arguments.insert(contentsOf: ["-H", "Authorization: Bearer \(token)"], at: arguments.count - 1)
  }
  if let body {
    arguments.insert(contentsOf: ["-H", "Content-Type: application/json", "--data", body], at: arguments.count - 1)
  }
  process.arguments = arguments

  let stdout = Pipe()
  let stderr = Pipe()
  process.standardOutput = stdout
  process.standardError = stderr
  try await run(process)

  let output = stdout.fileHandleForReading.readDataToEndOfFile()
  if process.terminationStatus != 0 {
    let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "curl failed"
    throw NSError(domain: "VolumeControlTests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput])
  }

  return try parseCurlHTTPResponse(output)
}

/// Awaits the process without blocking the calling thread.
///
/// `Process.waitUntilExit()` parks the thread it is called on. Called from an
/// async test it parks a cooperative thread, and the pool only has as many
/// threads as the machine has cores. Several of these tests issue requests
/// concurrently, which on a small CI runner left no thread for the unstructured
/// Task that `ControlServer.route` uses to reach its delegate. The server never
/// answered, its watchdog closed the socket, and curl reported an empty reply —
/// a failure that looks like a server bug but is caused by the test harness.
private func run(_ process: Process) async throws {
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    process.terminationHandler = { _ in
      continuation.resume()
    }
    do {
      try process.run()
    } catch {
      process.terminationHandler = nil
      continuation.resume(throwing: error)
    }
  }
}

private func parseHTTPResponse(_ data: Data) throws -> TestHTTPResponse {
  guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
    throw NSError(domain: "VolumeControlTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
  }

  let headerData = data.subdata(in: 0..<separator.lowerBound)
  let body = data.subdata(in: separator.upperBound..<data.count)
  guard let headerString = String(data: headerData, encoding: .utf8) else {
    throw NSError(domain: "VolumeControlTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unreadable HTTP headers"])
  }

  let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false)
  guard let statusLine = lines.first else {
    throw NSError(domain: "VolumeControlTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing status line"])
  }

  let parts = statusLine.split(separator: " ")
  guard parts.count >= 2, let status = Int(parts[1]) else {
    throw NSError(domain: "VolumeControlTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid status line"])
  }

  return TestHTTPResponse(status: status, body: body)
}

private func parseCurlHTTPResponse(_ data: Data) throws -> TestHTTPResponse {
  let marker = Data("\r\n\r\n".utf8)
  guard let separator = data.range(of: marker, options: .backwards) else {
    throw NSError(domain: "VolumeControlTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
  }

  let headerBlock = data.subdata(in: 0..<separator.lowerBound)
  guard let headerString = String(data: headerBlock, encoding: .utf8),
        let statusLine = headerString
          .components(separatedBy: "\r\n")
          .last(where: { $0.hasPrefix("HTTP/") }) else {
    throw NSError(domain: "VolumeControlTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing status line"])
  }

  let parts = statusLine.split(separator: " ")
  guard parts.count >= 2, let status = Int(parts[1]) else {
    throw NSError(domain: "VolumeControlTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid status line"])
  }

  return TestHTTPResponse(status: status, body: data.subdata(in: separator.upperBound..<data.count))
}

private func XCTJSON(_ data: Data) throws -> [String: Any] {
  guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw NSError(domain: "VolumeControlTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "Expected JSON object"])
  }
  return json
}

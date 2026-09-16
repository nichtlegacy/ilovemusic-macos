import Foundation
import Testing
@testable import ILoveMusic

@Test
func clearCommandSendsExplicitNullActivity() throws {
  let command = try DiscordRichPresenceManager.makeClearActivityCommand(
    processID: 42,
    nonce: "clear-nonce"
  )

  let json = try #require(decodedJSONObject(command.jsonString))
  let args = try #require(json["args"] as? [String: Any])

  #expect(command.nonce == "clear-nonce")
  #expect(json["cmd"] as? String == "SET_ACTIVITY")
  #expect(json["nonce"] as? String == "clear-nonce")
  #expect(args["pid"] as? Int == 42)
  #expect(args.keys.contains("activity"))
  #expect(args["activity"] is NSNull)
}

@Test
func setActivityCommandIncludesListeningPayloadAndTrimmedButtonLabel() throws {
  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "A Very Long Station Name"
  payload.artist = "Massive Artist"
  payload.title = "An Extremely Long Track Title"
  payload.listenerCount = 1234
  payload.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
  payload.websiteURL = URL(string: "https://example.com/listen")
  payload.artworkURL = URL(string: "https://example.com/artwork.jpg")

  let command = try DiscordRichPresenceManager.makeSetActivityCommand(
    payload: payload,
    showButton: true,
    processID: 99,
    nonce: "set-nonce"
  )

  let json = try #require(decodedJSONObject(command.jsonString))
  let args = try #require(json["args"] as? [String: Any])
  let activity = try #require(args["activity"] as? [String: Any])
  let buttons = try #require(activity["buttons"] as? [[String: Any]])
  let assets = try #require(activity["assets"] as? [String: Any])
  let timestamps = try #require(activity["timestamps"] as? [String: Any])

  #expect(json["cmd"] as? String == "SET_ACTIVITY")
  #expect(json["nonce"] as? String == "set-nonce")
  #expect(args["pid"] as? Int == 99)
  #expect(activity["type"] as? Int == 2)
  #expect(activity["details"] as? String == "An Extremely Long Track Title")
  #expect(activity["state"] as? String == "Massive Artist")
  #expect(activity["details_url"] as? String == "https://example.com/listen")
  #expect(activity["state_url"] as? String == "https://example.com/listen")
  #expect(assets["large_image"] as? String == "https://example.com/artwork.jpg")
  #expect(assets["large_text"] as? String == "A Very Long Station Name")
  #expect(assets["large_url"] as? String == "https://example.com/listen")
  #expect(assets["small_image"] as? String == "https://ilovemusic.de/fileadmin/templates/img/iloveradio_icon_sw_400x400.png")
  #expect(assets["small_text"] as? String == "A Very Long Station Name")
  #expect(assets["small_url"] as? String == "https://example.com/listen")
  #expect(timestamps["start"] as? Int == 1_700_000_000)
  #expect(buttons.count == 1)
  #expect(buttons[0]["url"] as? String == "https://example.com/listen")
  #expect(buttons[0]["label"] as? String == "Listen to A Very Long Station Na")
}

@Test
func setActivityCommandCanHideStationLogoBadge() throws {
  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "I Love Test"
  payload.title = "Track"
  payload.websiteURL = URL(string: "https://example.com/listen")
  payload.artworkURL = URL(string: "https://example.com/artwork.jpg")
  payload.showStationLogo = false

  let command = try DiscordRichPresenceManager.makeSetActivityCommand(
    payload: payload,
    showButton: true,
    processID: 99,
    nonce: "set-nonce"
  )

  let json = try #require(decodedJSONObject(command.jsonString))
  let args = try #require(json["args"] as? [String: Any])
  let activity = try #require(args["activity"] as? [String: Any])
  let assets = try #require(activity["assets"] as? [String: Any])

  #expect(assets["large_image"] as? String == "https://example.com/artwork.jpg")
  #expect(assets["large_url"] as? String == "https://example.com/listen")
  #expect(assets["small_image"] == nil)
  #expect(assets["small_text"] == nil)
  #expect(assets["small_url"] == nil)
}

@MainActor
@Test
func readySyncsQueuedPayloadAfterHandshake() async throws {
  let client = SpyDiscordIPCClient()
  let manager = DiscordRichPresenceManager(clientFactory: { client })
  manager.configure(clientID: "123")

  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "I Love Test"
  payload.artist = "Artist"
  payload.title = "Track"

  manager.start()
  manager.update(payload)
  manager.discordIPC(client, didReceiveMessage: #"{"evt":"READY"}"#)
  await Task.yield()

  let activityPayload = try #require(client.sentPayloads.last)
  let json = try #require(decodedJSONObject(activityPayload))
  let args = try #require(json["args"] as? [String: Any])
  let activity = try #require(args["activity"] as? [String: Any])

  #expect(activity["details"] as? String == "Track")
  #expect(activity["state"] as? String == "Artist")
}

@MainActor
@Test
func clearOverridesQueuedPayloadSoReconnectDoesNotResendStaleSong() async throws {
  let client = SpyDiscordIPCClient()
  let manager = DiscordRichPresenceManager(clientFactory: { client })
  manager.configure(clientID: "123")

  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "I Love Stale"
  payload.artist = "Old Artist"
  payload.title = "Old Track"

  manager.start()
  manager.update(payload)
  manager.clear()
  manager.discordIPC(client, didReceiveMessage: #"{"evt":"READY"}"#)
  await Task.yield()

  let activityPayload = try #require(client.sentPayloads.last)
  let json = try #require(decodedJSONObject(activityPayload))
  let args = try #require(json["args"] as? [String: Any])

  #expect(args["activity"] is NSNull)
}

@MainActor
@Test
func identicalPayloadIsNotResentToRespectRateLimit() async throws {
  let client = SpyDiscordIPCClient()
  let manager = DiscordRichPresenceManager(clientFactory: { client })
  manager.configure(clientID: "123")

  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "I Love Test"
  payload.artist = "Artist"
  payload.title = "Track"

  manager.start()
  manager.discordIPC(client, didReceiveMessage: #"{"evt":"READY"}"#)
  manager.update(payload)
  await Task.yield()
  let countAfterFirst = client.sentPayloads.count

  // Same payload again must be deduped — Discord drops rapid duplicate updates.
  manager.update(payload)
  await Task.yield()

  #expect(client.sentPayloads.count == countAfterFirst)
}

@MainActor
@Test
func closeReconnectsAndResyncsDesiredActivity() async throws {
  let client = SpyDiscordIPCClient()
  let manager = DiscordRichPresenceManager(clientFactory: { client })
  manager.configure(clientID: "123")

  var payload = DiscordRichPresenceManager.PresencePayload()
  payload.stationName = "I Love Test"
  payload.title = "Track"

  manager.start()
  manager.discordIPC(client, didReceiveMessage: #"{"evt":"READY"}"#)
  manager.update(payload)
  await Task.yield()

  // Discord drops the pipe.
  manager.discordIPCDidClose(client, reason: "heartbeat timeout")
  await Task.yield()

  // Manager must reconnect and resend the activity once Discord is READY again.
  manager.discordIPC(client, didReceiveMessage: #"{"evt":"READY"}"#)
  await Task.yield()

  let activityPayload = try #require(client.sentPayloads.last)
  let json = try #require(decodedJSONObject(activityPayload))
  let args = try #require(json["args"] as? [String: Any])
  let activity = try #require(args["activity"] as? [String: Any])
  #expect(activity["details"] as? String == "Track")
}

private func decodedJSONObject(_ jsonString: String) -> [String: Any]? {
  guard let data = jsonString.data(using: .utf8) else { return nil }
  return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private final class SpyDiscordIPCClient: DiscordIPCClient, @unchecked Sendable {
  var sentPayloads: [String] = []

  override func connect() {}

  override func disconnect() {}

  override func send(opcode: Int32, payload: String) {
    guard opcode == 1 else { return }
    sentPayloads.append(payload)
  }
}

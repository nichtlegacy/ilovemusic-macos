import Foundation
import Testing
@testable import ILoveMusic

@Test
func playHistoryStoreKeepsLatestEventVersion() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let store = PlayHistoryStore(fileURL: tempDir.appendingPathComponent("play_events.jsonl"))
  let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

  let openEvent = PlayEvent(
    id: UUID(),
    stationID: "radio",
    stationName: "I ♥ RADIO",
    stationCategory: .popHits,
    stationAccentHex: "#ffffff",
    artist: "Artist",
    title: "Track",
    artworkURLString: nil,
    startedAt: startedAt,
    endedAt: nil,
    listenedSeconds: nil,
    endReason: nil
  )

  var closedEvent = openEvent
  closedEvent.endedAt = startedAt.addingTimeInterval(120)
  closedEvent.listenedSeconds = 120
  closedEvent.endReason = .trackChanged

  store.append(openEvent)
  store.append(closedEvent, flushToDisk: true)

  let events = store.loadAll()
  #expect(events.count == 1)
  #expect(events.first?.endedAt == closedEvent.endedAt)
  #expect(events.first?.listenedSeconds == 120)
  #expect(events.first?.endReason == .trackChanged)
}

@Test
func playHistoryStoreCompactionPreservesEventsAndKeepsFile() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let fileURL = tempDir.appendingPathComponent("play_events.jsonl")
  let store = PlayHistoryStore(fileURL: fileURL)
  let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

  // Append two distinct events, then re-append updated versions of each so the
  // file has more lines than unique events (the compaction de-dup case).
  var events: [PlayEvent] = []
  for index in 0..<2 {
    var event = PlayEvent(
      id: UUID(),
      stationID: "radio",
      stationName: "I ♥ RADIO",
      stationCategory: .popHits,
      stationAccentHex: "#ffffff",
      artist: "Artist \(index)",
      title: "Track \(index)",
      artworkURLString: nil,
      startedAt: startedAt.addingTimeInterval(Double(index) * 60),
      endedAt: nil,
      listenedSeconds: nil,
      endReason: nil
    )
    store.append(event)
    event.endedAt = event.startedAt.addingTimeInterval(120)
    event.listenedSeconds = 120
    event.endReason = .trackChanged
    store.append(event, flushToDisk: true)
    events.append(event)
  }

  store.compact()

  // The on-disk file must still exist after the atomic rewrite swap.
  #expect(FileManager.default.fileExists(atPath: fileURL.path))

  let reloaded = store.loadAll()
  #expect(reloaded.count == 2)
  #expect(Set(reloaded.map(\.id)) == Set(events.map(\.id)))
  #expect(reloaded.allSatisfy { $0.listenedSeconds == 120 })
}

@MainActor
@Test
func recorderSplitsTracksAndSubtractsBufferingTime() {
  let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
  var now = startedAt
  let store = PlayHistoryStore(fileURL: FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("play_events.jsonl"))
  let recorder = PlayHistoryRecorder(store: store, nowProvider: { now })

  let station = Station(
    id: "radio",
    remoteID: "1",
    name: "I LOVE RADIO",
    slug: "radio",
    category: .popHits,
    accentHex: "#ffffff",
    aacStreamURLString: nil,
    mp3StreamURLString: nil,
    m3uURLString: nil,
    websiteURLString: "https://example.com",
    iconURLString: nil,
    tagline: "Main",
    featured: true,
    listenerCount: nil
  )

  let firstTrack = NowPlaying(
    stationID: station.id,
    artist: "First Artist",
    title: "First Track",
    artworkURLString: nil,
    updatedAt: now
  )
  let secondTrack = NowPlaying(
    stationID: station.id,
    artist: "Second Artist",
    title: "Second Track",
    artworkURLString: nil,
    updatedAt: now
  )

  recorder.refresh(
    station: station,
    metadata: firstTrack,
    state: PlaybackState(stationID: station.id, phase: .playing, resolvedStreamURLString: nil, errorMessage: nil, streamKind: nil)
  )

  now = startedAt.addingTimeInterval(80)
  recorder.refresh(
    station: station,
    metadata: firstTrack,
    state: PlaybackState(stationID: station.id, phase: .buffering, resolvedStreamURLString: nil, errorMessage: nil, streamKind: nil)
  )

  now = startedAt.addingTimeInterval(100)
  recorder.refresh(
    station: station,
    metadata: firstTrack,
    state: PlaybackState(stationID: station.id, phase: .playing, resolvedStreamURLString: nil, errorMessage: nil, streamKind: nil)
  )

  now = startedAt.addingTimeInterval(160)
  recorder.refresh(
    station: station,
    metadata: secondTrack,
    state: PlaybackState(stationID: station.id, phase: .playing, resolvedStreamURLString: nil, errorMessage: nil, streamKind: nil)
  )

  now = startedAt.addingTimeInterval(220)
  recorder.closeOpenEvent(reason: .paused)

  let events = recorder.events
  #expect(events.count == 2)
  #expect(events[0].artist == "First Artist")
  #expect(events[0].listenedSeconds == 140)
  #expect(events[0].endReason == .trackChanged)
  #expect(events[1].artist == "Second Artist")
  #expect(events[1].listenedSeconds == 60)
  #expect(events[1].endReason == .paused)
}

@MainActor
@Test
func recorderDropsShortEventsAndRecoversOpenEvents() {
  let startedAt = Date(timeIntervalSince1970: 1_700_100_000)
  var now = startedAt
  let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("play_events.jsonl")
  let store = PlayHistoryStore(fileURL: fileURL)
  let recorder = PlayHistoryRecorder(store: store, nowProvider: { now })

  let station = Station(
    id: "radio",
    remoteID: "1",
    name: "I LOVE RADIO",
    slug: "radio",
    category: .popHits,
    accentHex: "#ffffff",
    aacStreamURLString: nil,
    mp3StreamURLString: nil,
    m3uURLString: nil,
    websiteURLString: "https://example.com",
    iconURLString: nil,
    tagline: "Main",
    featured: true,
    listenerCount: nil
  )

  let metadata = NowPlaying(
    stationID: station.id,
    artist: "Artist",
    title: "Track",
    artworkURLString: nil,
    updatedAt: now
  )

  recorder.refresh(
    station: station,
    metadata: metadata,
    state: PlaybackState(stationID: station.id, phase: .playing, resolvedStreamURLString: nil, errorMessage: nil, streamKind: nil)
  )
  now = startedAt.addingTimeInterval(5)
  recorder.closeOpenEvent(reason: .paused)

  #expect(recorder.events.isEmpty)
  #expect(store.loadAll().isEmpty)

  let openEvent = PlayEvent(
    id: UUID(),
    stationID: station.id,
    stationName: station.displayName,
    stationCategory: station.category,
    stationAccentHex: station.accentHex,
    artist: metadata.artist,
    title: metadata.title,
    artworkURLString: nil,
    startedAt: startedAt,
    endedAt: nil,
    listenedSeconds: nil,
    endReason: nil
  )
  store.append(openEvent)

  now = startedAt.addingTimeInterval(30)
  recorder.bootstrap()

  let recoveredEvents = recorder.events
  #expect(recoveredEvents.count == 1)
  #expect(recoveredEvents[0].endReason == .crashRecovery)
  #expect(recoveredEvents[0].listenedSeconds == 30)
}

// MARK: - Data-loss protection (stats survival across version/schema drift)

@Test
func playHistoryToleratesUnknownEnumRawValueInsteadOfDroppingEvent() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let fileURL = tempDir.appendingPathComponent("play_events.jsonl")
  // Simulates a line written by a future/other version whose stationCategory
  // and endReason enums have a case this build doesn't know. Must NOT drop it.
  let line = ##"{"id":"00000000-0000-0000-0000-000000000001","stationID":"radio","stationName":"I love","stationCategory":"someFutureGenre","stationAccentHex":"#fff","artist":"A","title":"T","startedAt":"2023-11-14T22:13:20Z","endedAt":"2023-11-14T22:15:20Z","listenedSeconds":120,"endReason":"someFutureReason"}"##
  try (line + "\n").data(using: .utf8)!.write(to: fileURL)

  let store = PlayHistoryStore(fileURL: fileURL)
  let events = store.loadAll()

  #expect(events.count == 1)
  #expect(events.first?.stationCategory == .misc)   // unknown -> fallback
  #expect(events.first?.endReason == nil)           // unknown optional -> nil
  #expect(events.first?.listenedSeconds == 120)     // real data preserved
}

@Test
func playHistoryDoesNotWipeFileWhenEveryLineFailsToDecode() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let fileURL = tempDir.appendingPathComponent("play_events.jsonl")
  // 250 lines that genuinely cannot decode (missing required id/startedAt).
  // Old behaviour: loadAll sees lineCount>200, uniqueCount==0 -> compacts ->
  // rewrites the file empty, destroying recoverable history.
  let garbage = Array(repeating: #"{"broken":true}"#, count: 250).joined(separator: "\n") + "\n"
  let original = garbage.data(using: .utf8)!
  try original.write(to: fileURL)

  let store = PlayHistoryStore(fileURL: fileURL)
  _ = store.loadAll()
  store.compact()

  // File must be left intact, not truncated to empty.
  let after = try Data(contentsOf: fileURL)
  #expect(after.count == original.count)
}

@Test
func playHistoryDoesNotRewriteFileWithInvalidUTF8() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let fileURL = tempDir.appendingPathComponent("play_events.jsonl")
  let original = Data([0xFF, 0xFE, 0x0A])
  try original.write(to: fileURL)

  let store = PlayHistoryStore(fileURL: fileURL)
  store.compact()

  #expect(try Data(contentsOf: fileURL) == original)
}

@Test
func playHistoryDoesNotDropUnknownLinesDuringCompaction() throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let fileURL = tempDir.appendingPathComponent("play_events.jsonl")
  let validLine = ##"{"id":"00000000-0000-0000-0000-000000000001","stationID":"radio","stationName":"I love","stationCategory":"popHits","stationAccentHex":"#fff","artist":"A","title":"T","startedAt":"2023-11-14T22:13:20Z"}"##
  // Enough duplicate lines to trigger automatic compaction, plus one line
  // this build cannot decode. Neither automatic nor explicit compaction may
  // discard the unknown line.
  let originalText = Array(repeating: validLine, count: 201).joined(separator: "\n")
    + "\n" + #"{"futureRequiredShape":true}"# + "\n"
  let original = Data(originalText.utf8)
  try original.write(to: fileURL)

  let store = PlayHistoryStore(fileURL: fileURL)
  #expect(store.loadAll().count == 1)
  #expect(try Data(contentsOf: fileURL) == original)
  store.compact()

  #expect(try Data(contentsOf: fileURL) == original)
}

import Foundation
import Observation
import Testing
@testable import ILoveMusic

@Test
func snapshotHandlesEmptyInput() {
  let now = Date(timeIntervalSince1970: 1_700_000_000)
  let snapshot = PlayHistoryStats.snapshot(
    events: [],
    window: .last7Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.hasAnyEvents == false)
  #expect(snapshot.totalListenedSecondsInWindow == 0)
  #expect(snapshot.topChannels.isEmpty)
  #expect(snapshot.genreShares.isEmpty)
  #expect(snapshot.dailyStreak == 0)
  #expect(snapshot.averageSessionSeconds == 0)
}

@Test
func snapshotComputesSingleEventTotals() {
  let now = date("2023-11-18T12:00:00Z")
  let event = synthEvent(
    stationID: "radio",
    stationName: "I ♥ RADIO",
    category: .popHits,
    artist: "Drake",
    title: "Track",
    start: date("2023-11-18T11:00:00Z"),
    end: date("2023-11-18T11:03:00Z"),
    listened: 180
  )

  let snapshot = PlayHistoryStats.snapshot(
    events: [event],
    window: .today,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.totalListenedSecondsInWindow == 180)
  #expect(snapshot.totalListenedSecondsToday == 180)
  #expect(snapshot.topChannels.first?.stationID == "radio")
  #expect(snapshot.topArtists.first?.artist == "Drake")
  #expect(snapshot.hourOfDayBuckets[11] == 180)
  // A single session has an average: its own length.
  #expect(snapshot.averageSessionSeconds == 180)
}

@Test
func snapshotAveragesEventsGroupedIntoOneSession() {
  let now = date("2023-11-18T12:00:00Z")
  let events = [
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "First",
      start: date("2023-11-18T11:00:00Z"),
      end: date("2023-11-18T11:03:00Z"),
      listened: 180
    ),
    // Five minutes later, inside the 15-minute session gap, so both events
    // belong to the same session and the gap itself is not counted.
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "Second",
      start: date("2023-11-18T11:08:00Z"),
      end: date("2023-11-18T11:10:00Z"),
      listened: 120
    )
  ]

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .today,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.averageSessionSeconds == 300)
}

@Test
func snapshotSplitsSessionsSeparatedByMoreThanFifteenMinutes() {
  let now = date("2023-11-18T14:00:00Z")
  let events = [
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "First",
      start: date("2023-11-18T11:00:00Z"),
      end: date("2023-11-18T11:03:00Z"),
      listened: 180
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "Second",
      start: date("2023-11-18T13:00:00Z"),
      end: date("2023-11-18T13:02:00Z"),
      listened: 120
    )
  ]

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .today,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.averageSessionSeconds == 150)
}

@Test
func rollingWindowTotalMatchesTrendChartSum() {
  let now = date("2023-11-18T09:00:00Z")
  let events = [
    // Within the old rolling start of `now - 7 * 86_400` (2023-11-11T09:00Z),
    // but on a calendar day the chart never drew, so it inflated the window
    // total without ever appearing as a bar.
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "Straddling",
      start: date("2023-11-11T20:00:00Z"),
      end: date("2023-11-11T20:30:00Z"),
      listened: 1_800
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "Inside",
      start: date("2023-11-12T01:00:00Z"),
      end: date("2023-11-12T01:30:00Z"),
      listened: 1_800
    )
  ]

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .last7Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  let trendSum = snapshot.dailyTrend.reduce(0) { $0 + $1.listenedSeconds }
  #expect(snapshot.dailyTrend.count == 7)
  #expect(snapshot.dailyTrend.first?.date == date("2023-11-12T00:00:00Z"))
  #expect(snapshot.totalListenedSecondsInWindow == 1_800)
  #expect(trendSum == snapshot.totalListenedSecondsInWindow)
}

@Test
func customWindowAnchorsTrendBucketsToItsOwnRange() {
  let now = date("2023-11-18T09:00:00Z")
  let start = date("2023-10-02T00:00:00Z")
  let end = date("2023-10-04T23:59:59Z")
  let event = synthEvent(
    stationID: "radio",
    stationName: "I ♥ RADIO",
    category: .popHits,
    artist: "Drake",
    title: "Past",
    start: date("2023-10-03T10:00:00Z"),
    end: date("2023-10-03T10:30:00Z"),
    listened: 1_800
  )

  let snapshot = PlayHistoryStats.snapshot(
    events: [event],
    window: .custom(start: start, end: end),
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  // Buckets used to end at today regardless of the custom range, so a past
  // range produced bars for days it does not cover and lost its own events.
  #expect(snapshot.dailyTrend.count == 3)
  #expect(snapshot.dailyTrend.first?.date == date("2023-10-02T00:00:00Z"))
  #expect(snapshot.dailyTrend.last?.date == date("2023-10-04T00:00:00Z"))
  #expect(snapshot.dailyTrend.reduce(0) { $0 + $1.listenedSeconds } == 1_800)
}

@Test
func snapshotClipsAndDistributesAcrossHourBoundaries() {
  let now = date("2023-11-18T02:00:00Z")
  let event = synthEvent(
    stationID: "night",
    stationName: "I ♥ NIGHT",
    category: .danceDJ,
    artist: "DJ",
    title: "Late Set",
    start: date("2023-11-17T23:30:00Z"),
    end: date("2023-11-18T01:00:00Z"),
    listened: 5_400
  )

  let snapshot = PlayHistoryStats.snapshot(
    events: [event],
    window: .last7Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.hourOfDayBuckets[23] == 1_800)
  #expect(snapshot.hourOfDayBuckets[0] == 3_600)
  #expect(snapshot.weekdayHourHeatmap[4][23] == 1_800)
  #expect(snapshot.weekdayHourHeatmap[5][0] == 3_600)
}

@Test
func snapshotBuildsStreakAndAverageSessions() {
  let now = date("2023-11-16T10:00:00Z")
  let events = [
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "A",
      title: "One",
      start: date("2023-11-13T08:00:00Z"),
      end: date("2023-11-13T08:05:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "A",
      title: "Two",
      start: date("2023-11-14T08:00:00Z"),
      end: date("2023-11-14T08:05:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "A",
      title: "Three",
      start: date("2023-11-15T08:00:00Z"),
      end: date("2023-11-15T08:05:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "A",
      title: "Four",
      start: date("2023-11-15T08:10:00Z"),
      end: date("2023-11-15T08:15:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "radio",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "A",
      title: "Five",
      start: date("2023-11-15T09:00:00Z"),
      end: date("2023-11-15T09:05:00Z"),
      listened: 300
    )
  ]

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .last7Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.dailyStreak == 3)
  #expect(snapshot.averageSessionSeconds == 375)
}

@Test
func streakDistributesListeningAcrossMidnight() {
  let now = date("2023-11-18T12:00:00Z")
  let event = synthEvent(
    stationID: "night",
    stationName: "I ♥ NIGHT",
    category: .danceDJ,
    artist: "DJ",
    title: "Midnight Set",
    start: date("2023-11-17T23:58:00Z"),
    end: date("2023-11-18T00:02:00Z"),
    listened: 240
  )

  let snapshot = PlayHistoryStats.snapshot(
    events: [event],
    window: .last7Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.dailyTrend.suffix(2).map(\.listenedSeconds) == [120, 120])
  #expect(snapshot.dailyStreak == 2)
}

@Test
func snapshotCanonicalizesArtistsCapsTopNAndRebindsGenres() {
  let now = date("2023-11-18T23:59:00Z")
  var events: [PlayEvent] = [
    synthEvent(
      stationID: "station-0",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "Drake",
      title: "One",
      start: date("2023-11-18T09:00:00Z"),
      end: date("2023-11-18T09:05:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "station-0",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "DRAKE",
      title: "Two",
      start: date("2023-11-18T09:10:00Z"),
      end: date("2023-11-18T09:15:00Z"),
      listened: 300
    ),
    synthEvent(
      stationID: "station-0",
      stationName: "I ♥ RADIO",
      category: .popHits,
      artist: "drake",
      title: "Three",
      start: date("2023-11-18T09:20:00Z"),
      end: date("2023-11-18T09:25:00Z"),
      listened: 300
    )
  ]

  for index in 1..<30 {
    events.append(
      synthEvent(
        stationID: "station-\(index)",
        stationName: "I ♥ \(index)",
        category: .misc,
        artist: "Artist \(index)",
        title: "Track \(index)",
        start: date("2023-11-18T10:00:00Z").addingTimeInterval(Double(index * 600)),
        end: date("2023-11-18T10:05:00Z").addingTimeInterval(Double(index * 600)),
        listened: 300
      )
    )
  }

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .last30Days,
    stationLookup: [
      "station-0": Station(
        id: "station-0",
        remoteID: "0",
        name: "I LOVE RADIO",
        slug: "radio",
        category: .chill,
        accentHex: "#00aaff",
        aacStreamURLString: nil,
        mp3StreamURLString: nil,
        m3uURLString: nil,
        websiteURLString: "https://example.com",
        iconURLString: nil,
        tagline: "Main",
        featured: true,
        listenerCount: nil
      )
    ],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.topArtists.first?.artist == "Drake")
  #expect(snapshot.topChannels.count == 20)
  #expect(snapshot.genreShares.contains { $0.category == .chill && $0.listenedSeconds == 900 })
}

@Test
func snapshotZeroFillsTrendAndIgnoresOpenEvents() {
  let now = date("2023-11-30T12:00:00Z")
  let openEvent = PlayEvent(
    id: UUID(),
    stationID: "open",
    stationName: "I ♥ OPEN",
    stationCategory: .misc,
    stationAccentHex: "#ffffff",
    artist: "Artist",
    title: "Open",
    artworkURLString: nil,
    startedAt: date("2023-11-30T10:00:00Z"),
    endedAt: nil,
    listenedSeconds: nil,
    endReason: nil
  )
  let events = [
    synthEvent(
      stationID: "one",
      stationName: "I ♥ ONE",
      category: .misc,
      artist: "Artist",
      title: "Track",
      start: date("2023-11-02T10:00:00Z"),
      end: date("2023-11-02T10:10:00Z"),
      listened: 600
    ),
    synthEvent(
      stationID: "two",
      stationName: "I ♥ TWO",
      category: .misc,
      artist: "Artist",
      title: "Track",
      start: date("2023-11-20T10:00:00Z"),
      end: date("2023-11-20T10:10:00Z"),
      listened: 600
    ),
    openEvent
  ]

  let snapshot = PlayHistoryStats.snapshot(
    events: events,
    window: .last30Days,
    stationLookup: [:],
    now: now,
    calendar: fixedCalendar
  )

  #expect(snapshot.eventCountInWindow == 2)
  #expect(snapshot.dailyTrend.count == 30)
  #expect(snapshot.dailyTrend.filter { $0.listenedSeconds == 0 }.count == 28)
}

@MainActor
@Test
func appModelCachesSnapshotsAndInvalidatesOnRecorderMutation() {
  let playbackController = PlaybackController()
  let appModel = AppModel(playbackController: playbackController)

  _ = appModel.statsSnapshot(for: .lifetime)
  _ = appModel.statsSnapshot(for: .lifetime)
  #expect(appModel.statsSnapshotComputeCount == 1)

  let revision = appModel.statsSnapshotRevision
  appModel.historyRecorder.onEventsChanged?()
  #expect(appModel.statsSnapshotRevision == revision + 1)
  _ = appModel.statsSnapshot(for: .lifetime)
  #expect(appModel.statsSnapshotComputeCount == 2)
}

@MainActor
@Test
func cachedSnapshotStillObservesRecorderInvalidation() async {
  let appModel = AppModel(playbackController: PlaybackController())
  let probe = StatsObservationProbe()

  _ = appModel.statsSnapshot(for: .lifetime)
  withObservationTracking {
    _ = appModel.statsSnapshot(for: .lifetime)
  } onChange: {
    Task { @MainActor in probe.changed = true }
  }

  appModel.historyRecorder.onEventsChanged?()

  #expect(await waitUntil { probe.changed })
}

@MainActor
@Test
func appModelKeepsDiscordSessionAcrossPauseChannelChangeAndResetsAfterGracePeriod() async throws {
  let playbackController = PlaybackController()
  let appModel = AppModel(
    playbackController: playbackController,
    discordSessionGracePeriod: .seconds(1)
  )

  let nextStation = Station(
    id: "next",
    remoteID: "2",
    name: "ILoveMusic NEXT",
    slug: "next",
    category: .popHits,
    accentHex: "#ffffff",
    aacStreamURLString: nil,
    mp3StreamURLString: nil,
    m3uURLString: nil,
    websiteURLString: "https://example.com",
    iconURLString: nil,
    tagline: "Next",
    featured: true,
    listenerCount: nil
  )

  playbackController.onPlaybackStateChanged?(
    PlaybackState(
      stationID: "radio",
      phase: .playing,
      resolvedStreamURLString: nil,
      errorMessage: nil,
      streamKind: nil
    )
  )
  await Task.yield()

  let startedAt = try #require(appModel.channelStartedAt)

  playbackController.onPlaybackStateChanged?(
    PlaybackState(
      stationID: "radio",
      phase: .paused,
      resolvedStreamURLString: nil,
      errorMessage: nil,
      streamKind: nil
    )
  )
  await Task.yield()
  #expect(appModel.channelStartedAt == startedAt)

  playbackController.onPlaybackStateChanged?(
    PlaybackState(
      stationID: "radio",
      phase: .playing,
      resolvedStreamURLString: nil,
      errorMessage: nil,
      streamKind: nil
    )
  )
  await Task.yield()
  #expect(appModel.channelStartedAt == startedAt)

  appModel.activeStationID = "radio"
  await appModel.play(nextStation)
  #expect(appModel.channelStartedAt == startedAt)

  playbackController.onPlaybackStateChanged?(
    PlaybackState(
      stationID: "radio",
      phase: .paused,
      resolvedStreamURLString: nil,
      errorMessage: nil,
      streamKind: nil
    )
  )
  // The reset fires one grace period after the pause and then hops to the main
  // actor. Sleeping a fixed 1100 ms left 100 ms for both of those, which a
  // loaded CI runner does not reliably deliver. Poll instead: still quick when
  // the machine is idle, and no longer a coin flip when it is not.
  #expect(await waitUntil { appModel.channelStartedAt == nil })
}

/// Polls `condition` until it holds or `timeout` elapses, and reports the final
/// result. Preferred over a fixed sleep for anything a scheduler decides.
@MainActor
private func waitUntil(
  timeout: Duration = .seconds(10),
  _ condition: () -> Bool,
) async -> Bool {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if condition() { return true }
    try? await Task.sleep(for: .milliseconds(20))
  }
  return condition()
}

private let fixedCalendar: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
  return calendar
}()

@MainActor
private final class StatsObservationProbe {
  var changed = false
}

private func date(_ value: String) -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
}

private func synthEvent(
  stationID: String,
  stationName: String,
  category: StationCategory,
  artist: String,
  title: String,
  start: Date,
  end: Date,
  listened: Double,
  accentHex: String = "#ffffff"
) -> PlayEvent {
  PlayEvent(
    id: UUID(),
    stationID: stationID,
    stationName: stationName,
    stationCategory: category,
    stationAccentHex: accentHex,
    artist: artist,
    title: title,
    artworkURLString: nil,
    startedAt: start,
    endedAt: end,
    listenedSeconds: listened,
    endReason: .trackChanged
  )
}

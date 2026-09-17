import Foundation

struct StatsSnapshot: Hashable {
  let window: HistoryWindow
  let computedAt: Date
  let totalListenedSecondsToday: Double
  let totalListenedSecondsThisWeek: Double
  let totalListenedSecondsThisMonth: Double
  let totalListenedSecondsLifetime: Double
  let totalListenedSecondsInWindow: Double
  let dailyStreak: Int
  let topChannels: [ChannelTotal]
  let topArtists: [ArtistTotal]
  let topSongs: [SongTotal]
  let hourOfDayBuckets: [Double]
  let weekdayHourHeatmap: [[Double]]
  let genreShares: [GenreShare]
  let dailyTrend: [DailyBucket]
  let averageSessionSeconds: Double
  let hasAnyEvents: Bool
  let eventCountInWindow: Int
}

struct ChannelTotal: Hashable, Identifiable {
  let stationID: String
  let stationName: String
  let accentHex: String
  let listenedSeconds: Double
  let playCount: Int

  var id: String { stationID }
}

struct ArtistTotal: Hashable, Identifiable {
  let artist: String
  let listenedSeconds: Double
  let playCount: Int

  var id: String { artist }
}

struct SongTotal: Hashable, Identifiable {
  let artist: String
  let title: String
  let artworkURLString: String?
  let listenedSeconds: Double
  let playCount: Int

  var id: String { "\(artist)␞\(title)" }
}

struct GenreShare: Hashable, Identifiable {
  let category: StationCategory
  let listenedSeconds: Double
  let share: Double

  var id: String { category.rawValue }
}

struct DailyBucket: Hashable, Identifiable {
  let date: Date
  let listenedSeconds: Double

  var id: Date { date }
}

struct PlayHistoryStats {
  static func snapshot(
    events: [PlayEvent],
    window: HistoryWindow,
    stationLookup: [String: Station],
    now: Date = .now,
    calendar: Calendar = .current
  ) -> StatsSnapshot {
    let validLifetimeEvents = closedEligibleEvents(events)
    let inWindowEvents = clippedEvents(events: validLifetimeEvents, window: window, now: now, calendar: calendar)
    let totalInWindow = inWindowEvents.reduce(0) { $0 + $1.effectiveSeconds }

    let topChannels = channelTotals(for: inWindowEvents, stationLookup: stationLookup)
    let topArtists = artistTotals(for: inWindowEvents)
    let topSongs = songTotals(for: inWindowEvents)
    let hourBuckets = hourBuckets(for: inWindowEvents, calendar: calendar)
    let heatmap = weekdayHourHeatmap(for: inWindowEvents, calendar: calendar)
    let genreShares = genreShares(for: inWindowEvents, stationLookup: stationLookup, total: totalInWindow)
    let dailyTrend = dailyTrend(for: inWindowEvents, window: window, now: now, calendar: calendar)

    return StatsSnapshot(
      window: window,
      computedAt: now,
      totalListenedSecondsToday: totalSeconds(events: validLifetimeEvents, window: .today, now: now, calendar: calendar),
      totalListenedSecondsThisWeek: totalSeconds(events: validLifetimeEvents, window: .last7Days, now: now, calendar: calendar),
      totalListenedSecondsThisMonth: totalSeconds(events: validLifetimeEvents, window: .last30Days, now: now, calendar: calendar),
      totalListenedSecondsLifetime: totalSeconds(events: validLifetimeEvents, window: .lifetime, now: now, calendar: calendar),
      totalListenedSecondsInWindow: totalInWindow,
      dailyStreak: dailyStreak(events: validLifetimeEvents, now: now, calendar: calendar),
      topChannels: topChannels,
      topArtists: topArtists,
      topSongs: topSongs,
      hourOfDayBuckets: hourBuckets,
      weekdayHourHeatmap: heatmap,
      genreShares: genreShares,
      dailyTrend: dailyTrend,
      averageSessionSeconds: averageSessionSeconds(for: inWindowEvents),
      hasAnyEvents: !validLifetimeEvents.isEmpty,
      eventCountInWindow: inWindowEvents.count
    )
  }

  private static func closedEligibleEvents(_ events: [PlayEvent]) -> [PlayEvent] {
    events.filter {
      $0.endedAt != nil && ($0.listenedSeconds ?? 0) >= PlayHistoryRecorder.minimumListenSeconds
    }
  }

  private static func totalSeconds(
    events: [PlayEvent],
    window: HistoryWindow,
    now: Date,
    calendar: Calendar
  ) -> Double {
    clippedEvents(events: events, window: window, now: now, calendar: calendar)
      .reduce(0) { $0 + $1.effectiveSeconds }
  }

  private static func clippedEvents(
    events: [PlayEvent],
    window: HistoryWindow,
    now: Date,
    calendar: Calendar
  ) -> [ClippedEvent] {
    let range = window.dateRange(now: now, calendar: calendar)

    return events.compactMap { event in
      guard
        let endedAt = event.endedAt,
        let listened = event.listenedSeconds,
        listened > 0
      else {
        return nil
      }

      let clippedStart = max(event.startedAt, range.start)
      let clippedEnd = min(endedAt, range.end)
      guard clippedEnd > clippedStart else { return nil }

      let totalWall = endedAt.timeIntervalSince(event.startedAt)
      guard totalWall > 0 else { return nil }

      let clippedWall = clippedEnd.timeIntervalSince(clippedStart)
      let effectiveSeconds = listened * (clippedWall / totalWall)
      guard effectiveSeconds > 0 else { return nil }

      return ClippedEvent(
        source: event,
        clippedStart: clippedStart,
        clippedEnd: clippedEnd,
        effectiveSeconds: effectiveSeconds
      )
    }
  }

  private static func channelTotals(
    for events: [ClippedEvent],
    stationLookup: [String: Station]
  ) -> [ChannelTotal] {
    var buckets: [String: ChannelAccumulator] = [:]

    for event in events {
      let station = stationLookup[event.source.stationID]
      let name = station?.displayName ?? event.source.stationName
      let accent = station?.accentHex ?? event.source.stationAccentHex
      buckets[event.source.stationID, default: ChannelAccumulator(stationName: name, accentHex: accent, listenedSeconds: 0, playCount: 0)]
        .append(name: name, accentHex: accent, seconds: event.effectiveSeconds)
    }

    return buckets
      .map {
        ChannelTotal(
          stationID: $0.key,
          stationName: $0.value.stationName,
          accentHex: $0.value.accentHex,
          listenedSeconds: $0.value.listenedSeconds,
          playCount: $0.value.playCount
        )
      }
      .sorted {
        if $0.listenedSeconds != $1.listenedSeconds {
          return $0.listenedSeconds > $1.listenedSeconds
        }
        return $0.stationName.localizedCaseInsensitiveCompare($1.stationName) == .orderedAscending
      }
      .prefix(20)
      .map { $0 }
  }

  private static func artistTotals(for events: [ClippedEvent]) -> [ArtistTotal] {
    var buckets: [String: VariantAccumulator] = [:]

    for event in events {
      let artist = event.source.artist.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !artist.isEmpty else { continue }
      let key = artist.lowercased()
      var bucket = buckets[key] ?? VariantAccumulator()
      bucket.listenedSeconds += event.effectiveSeconds
      bucket.playCount += 1
      bucket.variantCounts[artist, default: 0] += 1
      buckets[key] = bucket
    }

    return buckets
      .map { key, bucket in
        ArtistTotal(
          artist: bucket.preferredVariant(fallback: key),
          listenedSeconds: bucket.listenedSeconds,
          playCount: bucket.playCount
        )
      }
      .sorted {
        if $0.listenedSeconds != $1.listenedSeconds {
          return $0.listenedSeconds > $1.listenedSeconds
        }
        return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
      }
      .prefix(20)
      .map { $0 }
  }

  private static func songTotals(for events: [ClippedEvent]) -> [SongTotal] {
    var buckets: [String: SongAccumulator] = [:]

    for event in events {
      let artist = event.source.artist.trimmingCharacters(in: .whitespacesAndNewlines)
      let title = event.source.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !artist.isEmpty || !title.isEmpty else { continue }

      let key = "\(artist.lowercased())␞\(title.lowercased())"
      var bucket = buckets[key] ?? SongAccumulator()
      bucket.listenedSeconds += event.effectiveSeconds
      bucket.playCount += 1
      bucket.artistVariants[artist, default: 0] += 1
      bucket.titleVariants[title, default: 0] += 1
      bucket.artworkURLString = bucket.artworkURLString ?? event.source.artworkURLString
      buckets[key] = bucket
    }

    return buckets
      .map { key, bucket in
        let parts = key.split(separator: "␞", omittingEmptySubsequences: false)
        let fallbackArtist = parts.first.map(String.init) ?? ""
        let fallbackTitle = parts.count > 1 ? String(parts[1]) : ""

        return SongTotal(
          artist: bucket.preferredArtist(fallback: fallbackArtist),
          title: bucket.preferredTitle(fallback: fallbackTitle),
          artworkURLString: bucket.artworkURLString,
          listenedSeconds: bucket.listenedSeconds,
          playCount: bucket.playCount
        )
      }
      .sorted {
        if $0.listenedSeconds != $1.listenedSeconds {
          return $0.listenedSeconds > $1.listenedSeconds
        }
        if $0.artist.localizedCaseInsensitiveCompare($1.artist) != .orderedSame {
          return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
        }
        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
      .prefix(20)
      .map { $0 }
  }

  private static func hourBuckets(for events: [ClippedEvent], calendar: Calendar) -> [Double] {
    var buckets = Array(repeating: 0.0, count: 24)

    for event in events {
      for chunk in distributeAcrossHours(event: event, calendar: calendar) {
        buckets[chunk.hour] += chunk.seconds
      }
    }

    return buckets
  }

  private static func weekdayHourHeatmap(for events: [ClippedEvent], calendar: Calendar) -> [[Double]] {
    var matrix = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)

    for event in events {
      for chunk in distributeAcrossHours(event: event, calendar: calendar) {
        matrix[chunk.weekday][chunk.hour] += chunk.seconds
      }
    }

    return matrix
  }

  private static func genreShares(
    for events: [ClippedEvent],
    stationLookup: [String: Station],
    total: Double
  ) -> [GenreShare] {
    guard total > 0 else { return [] }

    var buckets: [StationCategory: Double] = [:]
    for event in events {
      let category = stationLookup[event.source.stationID]?.category ?? event.source.stationCategory
      buckets[category, default: 0] += event.effectiveSeconds
    }

    return buckets
      .map { category, seconds in
        GenreShare(category: category, listenedSeconds: seconds, share: seconds / total)
      }
      .sorted {
        if $0.listenedSeconds != $1.listenedSeconds {
          return $0.listenedSeconds > $1.listenedSeconds
        }
        return $0.category.title.localizedCaseInsensitiveCompare($1.category.title) == .orderedAscending
      }
  }

  private static func dailyTrend(
    for events: [ClippedEvent],
    window: HistoryWindow,
    now: Date,
    calendar: Calendar
  ) -> [DailyBucket] {
    let bucketDates = trendBucketDates(window: window, events: events, now: now, calendar: calendar)
    guard !bucketDates.isEmpty else { return [] }

    var buckets = Dictionary(uniqueKeysWithValues: bucketDates.map { ($0, 0.0) })

    for event in events {
      let distributed = distributeAcrossDays(event: event, calendar: calendar)
      for item in distributed where buckets[item.date] != nil {
        buckets[item.date, default: 0] += item.seconds
      }
    }

    return bucketDates.map { DailyBucket(date: $0, listenedSeconds: buckets[$0] ?? 0) }
  }

  private static func averageSessionSeconds(for events: [ClippedEvent]) -> Double {
    let sorted = events.sorted {
      if $0.clippedStart != $1.clippedStart {
        return $0.clippedStart < $1.clippedStart
      }
      return $0.source.id.uuidString < $1.source.id.uuidString
    }

    guard !sorted.isEmpty else { return 0 }

    var sessions: [Double] = []
    var current = 0.0
    var previousEnd: Date?

    for event in sorted {
      if let previousEnd, event.clippedStart.timeIntervalSince(previousEnd) > 15 * 60 {
        sessions.append(current)
        current = 0
      }
      current += event.effectiveSeconds
      previousEnd = event.clippedEnd
    }

    if current > 0 {
      sessions.append(current)
    }

    // An average is defined for any nonempty set of sessions. Requiring two
    // made a first listening session report "no average" instead of its own
    // length.
    guard !sessions.isEmpty else { return 0 }
    return sessions.reduce(0, +) / Double(sessions.count)
  }

  private static func dailyStreak(events: [PlayEvent], now: Date, calendar: Calendar) -> Int {
    guard !events.isEmpty else { return 0 }

    var dailyTotals: [Date: Double] = [:]
    for event in clippedEvents(events: events, window: .lifetime, now: now, calendar: calendar) {
      for item in distributeAcrossDays(event: event, calendar: calendar) {
        dailyTotals[item.date, default: 0] += item.seconds
      }
    }

    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

    let startingDay: Date
    if (dailyTotals[today] ?? 0) >= 60 {
      startingDay = today
    } else if (dailyTotals[yesterday] ?? 0) >= 60 {
      startingDay = yesterday
    } else {
      return 0
    }

    var streak = 0
    var cursor = startingDay
    while (dailyTotals[cursor] ?? 0) >= 60 {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  private static func distributeAcrossHours(
    event: ClippedEvent,
    calendar: Calendar
  ) -> [(hour: Int, weekday: Int, seconds: Double)] {
    let totalWall = event.clippedEnd.timeIntervalSince(event.clippedStart)
    guard totalWall > 0 else { return [] }

    var result: [(hour: Int, weekday: Int, seconds: Double)] = []
    var cursor = event.clippedStart

    while cursor < event.clippedEnd {
      let nextHourStart = calendar.dateInterval(of: .hour, for: cursor)?.end
        ?? cursor.addingTimeInterval(3600)
      let chunkEnd = min(nextHourStart, event.clippedEnd)
      let chunkWall = chunkEnd.timeIntervalSince(cursor)
      let seconds = event.effectiveSeconds * (chunkWall / totalWall)
      let components = calendar.dateComponents([.hour, .weekday], from: cursor)
      let weekday = ((components.weekday ?? 1) + 5) % 7
      result.append((components.hour ?? 0, weekday, seconds))
      cursor = chunkEnd
    }

    return result
  }

  private static func distributeAcrossDays(
    event: ClippedEvent,
    calendar: Calendar
  ) -> [(date: Date, seconds: Double)] {
    let totalWall = event.clippedEnd.timeIntervalSince(event.clippedStart)
    guard totalWall > 0 else { return [] }

    var result: [(date: Date, seconds: Double)] = []
    var cursor = event.clippedStart

    while cursor < event.clippedEnd {
      let nextDayStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor))
        ?? event.clippedEnd
      let chunkEnd = min(nextDayStart, event.clippedEnd)
      let chunkWall = chunkEnd.timeIntervalSince(cursor)
      let seconds = event.effectiveSeconds * (chunkWall / totalWall)
      result.append((calendar.startOfDay(for: cursor), seconds))
      cursor = chunkEnd
    }

    return result
  }

  private static func trendBucketDates(
    window: HistoryWindow,
    events: [ClippedEvent],
    now: Date,
    calendar: Calendar
  ) -> [Date] {
    let today = calendar.startOfDay(for: now)

    switch window {
    case .today:
      return [today]
    case .last7Days:
      return days(endingAt: today, count: 7, calendar: calendar)
    case .last30Days:
      return days(endingAt: today, count: 30, calendar: calendar)
    case .last90Days:
      return days(endingAt: today, count: 90, calendar: calendar)
    case .custom(let start, let end):
      // A custom window ends at its own end date, not today. Anchoring the
      // buckets to `today` shifted every bar of a past date range.
      let first = calendar.startOfDay(for: start)
      let last = calendar.startOfDay(for: end)
      let spanned = calendar.dateComponents([.day], from: first, to: last).day ?? 0
      return days(startingAt: first, count: max(1, spanned + 1), calendar: calendar)
    case .lifetime:
      guard
        let firstEvent = events.map(\.clippedStart).min(),
        let spanned = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstEvent), to: today).day
      else {
        return []
      }
      return days(endingAt: today, count: max(1, spanned + 1), calendar: calendar)
    }
  }

  private static func days(startingAt first: Date, count: Int, calendar: Calendar) -> [Date] {
    (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
  }

  private static func days(endingAt last: Date, count: Int, calendar: Calendar) -> [Date] {
    guard let first = calendar.date(byAdding: .day, value: -(count - 1), to: last) else { return [last] }
    return days(startingAt: first, count: count, calendar: calendar)
  }
}

private struct ClippedEvent: Hashable {
  let source: PlayEvent
  let clippedStart: Date
  let clippedEnd: Date
  let effectiveSeconds: Double
}

private struct ChannelAccumulator {
  var stationName: String
  var accentHex: String
  var listenedSeconds: Double
  var playCount: Int

  mutating func append(name: String, accentHex: String, seconds: Double) {
    stationName = name
    self.accentHex = accentHex
    listenedSeconds += seconds
    playCount += 1
  }
}

private struct VariantAccumulator {
  var listenedSeconds = 0.0
  var playCount = 0
  var variantCounts: [String: Int] = [:]

  func preferredVariant(fallback: String) -> String {
    variantCounts.keys.sorted { lhs, rhs in
      let leftCount = variantCounts[lhs] ?? 0
      let rightCount = variantCounts[rhs] ?? 0
      if leftCount != rightCount {
        return leftCount > rightCount
      }

      let leftStyle = capitalizationPreference(lhs)
      let rightStyle = capitalizationPreference(rhs)
      if leftStyle != rightStyle {
        return leftStyle > rightStyle
      }

      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }.first ?? fallback
  }
}

private struct SongAccumulator {
  var listenedSeconds = 0.0
  var playCount = 0
  var artistVariants: [String: Int] = [:]
  var titleVariants: [String: Int] = [:]
  var artworkURLString: String?

  func preferredArtist(fallback: String) -> String {
    artistVariants.keys.sorted { lhs, rhs in
      let leftCount = artistVariants[lhs] ?? 0
      let rightCount = artistVariants[rhs] ?? 0
      if leftCount != rightCount {
        return leftCount > rightCount
      }

      let leftStyle = capitalizationPreference(lhs)
      let rightStyle = capitalizationPreference(rhs)
      if leftStyle != rightStyle {
        return leftStyle > rightStyle
      }

      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }.first ?? fallback
  }

  func preferredTitle(fallback: String) -> String {
    titleVariants.keys.sorted { lhs, rhs in
      let leftCount = titleVariants[lhs] ?? 0
      let rightCount = titleVariants[rhs] ?? 0
      if leftCount != rightCount {
        return leftCount > rightCount
      }

      let leftStyle = capitalizationPreference(lhs)
      let rightStyle = capitalizationPreference(rhs)
      if leftStyle != rightStyle {
        return leftStyle > rightStyle
      }

      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }.first ?? fallback
  }
}

private func capitalizationPreference(_ value: String) -> Int {
  if value == value.uppercased(), value != value.lowercased() {
    return 1
  }
  if value == value.lowercased(), value != value.uppercased() {
    return 0
  }
  if let first = value.first, String(first) == String(first).uppercased() {
    return 2
  }
  return 1
}

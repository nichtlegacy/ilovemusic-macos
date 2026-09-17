import Foundation

struct PlayEvent: Codable, Identifiable, Hashable {
  let id: UUID
  let stationID: String
  let stationName: String
  let stationCategory: StationCategory
  let stationAccentHex: String
  let artist: String
  let title: String
  let artworkURLString: String?
  let startedAt: Date
  var endedAt: Date?
  var listenedSeconds: Double?
  var endReason: PlayEventEndReason?

  init(
    id: UUID,
    stationID: String,
    stationName: String,
    stationCategory: StationCategory,
    stationAccentHex: String,
    artist: String,
    title: String,
    artworkURLString: String?,
    startedAt: Date,
    endedAt: Date? = nil,
    listenedSeconds: Double? = nil,
    endReason: PlayEventEndReason? = nil
  ) {
    self.id = id
    self.stationID = stationID
    self.stationName = stationName
    self.stationCategory = stationCategory
    self.stationAccentHex = stationAccentHex
    self.artist = artist
    self.title = title
    self.artworkURLString = artworkURLString
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.listenedSeconds = listenedSeconds
    self.endReason = endReason
  }

  /// Tolerant decode: only `id` and `startedAt` are truly required. Enum fields
  /// (`stationCategory`, `endReason`) fall back instead of throwing, so a future
  /// rename or added enum case can never make a whole history file undecodable —
  /// which previously cascaded into the file being compacted away to empty.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    startedAt = try c.decode(Date.self, forKey: .startedAt)
    stationID = (try? c.decode(String.self, forKey: .stationID)) ?? ""
    stationName = (try? c.decode(String.self, forKey: .stationName)) ?? ""
    stationCategory = (try? c.decode(StationCategory.self, forKey: .stationCategory)) ?? .misc
    stationAccentHex = (try? c.decode(String.self, forKey: .stationAccentHex)) ?? ""
    artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
    title = (try? c.decode(String.self, forKey: .title)) ?? ""
    artworkURLString = (try? c.decodeIfPresent(String.self, forKey: .artworkURLString)) ?? nil
    endedAt = (try? c.decodeIfPresent(Date.self, forKey: .endedAt)) ?? nil
    listenedSeconds = (try? c.decodeIfPresent(Double.self, forKey: .listenedSeconds)) ?? nil
    endReason = (try? c.decodeIfPresent(PlayEventEndReason.self, forKey: .endReason)) ?? nil
  }
}

enum PlayEventEndReason: String, Codable {
  case trackChanged
  case stationChanged
  case paused
  case stopped
  case quit
  case crashRecovery
}

enum HistoryWindow: Equatable, Hashable {
  case today
  case last7Days
  case last30Days
  case last90Days
  case lifetime
  case custom(start: Date, end: Date)

  var titleResource: LocalizedStringResource {
    switch self {
    case .today: LocalizedStringResource("Today", bundle: #bundle)
    case .last7Days: LocalizedStringResource("7 Days", bundle: #bundle)
    case .last30Days: LocalizedStringResource("30 Days", bundle: #bundle)
    case .last90Days: LocalizedStringResource("90 Days", bundle: #bundle)
    case .lifetime: LocalizedStringResource("All Time", bundle: #bundle)
    case .custom: LocalizedStringResource("Custom Range", bundle: #bundle)
    }
  }

  func dateRange(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
    switch self {
    case .today:
      return (calendar.startOfDay(for: now), now)
    case .last7Days:
      return (Self.startOfDay(daysBefore: 6, from: now, calendar: calendar), now)
    case .last30Days:
      return (Self.startOfDay(daysBefore: 29, from: now, calendar: calendar), now)
    case .last90Days:
      return (Self.startOfDay(daysBefore: 89, from: now, calendar: calendar), now)
    case .lifetime:
      return (.distantPast, now)
    case .custom(let start, let end):
      return (start, end)
    }
  }

  /// Anchors the rolling windows to calendar day boundaries so a window covers
  /// exactly the days the trend chart draws. Subtracting multiples of 86,400
  /// seconds instead reached back into a partial extra day, and drifted by an
  /// hour across a daylight-saving change, so the window total and the sum of
  /// the chart's bars disagreed.
  private static func startOfDay(daysBefore days: Int, from now: Date, calendar: Calendar) -> Date {
    let today = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: -days, to: today) ?? today
  }
}

extension HistoryWindow: RawRepresentable {
  init?(rawValue: String) {
    switch rawValue {
    case "today":
      self = .today
    case "last7Days":
      self = .last7Days
    case "last30Days":
      self = .last30Days
    case "last90Days":
      self = .last90Days
    case "lifetime":
      self = .lifetime
    default:
      return nil
    }
  }

  var rawValue: String {
    switch self {
    case .today:
      return "today"
    case .last7Days:
      return "last7Days"
    case .last30Days:
      return "last30Days"
    case .last90Days:
      return "last90Days"
    case .lifetime:
      return "lifetime"
    case .custom:
      return "custom"
    }
  }
}

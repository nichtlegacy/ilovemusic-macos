import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
  case system
  case german = "de"
  case english = "en"

  var id: Self { self }

  var titleResource: LocalizedStringResource {
    switch self {
    case .system:
      LocalizedStringResource(
        "System Default",
        bundle: #bundle,
        comment: "Language picker option that follows the macOS app language."
      )
    case .german:
      LocalizedStringResource("Deutsch", bundle: #bundle, comment: "German language picker option.")
    case .english:
      LocalizedStringResource("English", bundle: #bundle, comment: "English language picker option.")
    }
  }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = Self(rawValue: rawValue) ?? .system
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

enum StationCategory: String, Codable, CaseIterable, Identifiable {
  case popHits
  case danceDJ
  case hipHop
  case throwbacks
  case chill
  case sport
  case party
  case specials
  case seasonal
  case misc

  var id: String { rawValue }

  var title: String {
    switch self {
    case .popHits: "Pop & Hits"
    case .danceDJ: "Dance & DJ"
    case .hipHop: "Hip Hop"
    case .throwbacks: "Throwbacks"
    case .chill: "Chill"
    case .sport: "Workout"
    case .party: "Party"
    case .specials: "Specials"
    case .seasonal: "Seasonal"
    case .misc: "Misc"
    }
  }

  var titleResource: LocalizedStringResource {
    switch self {
    case .popHits: LocalizedStringResource("Pop & Hits", bundle: #bundle, comment: "Station category name.")
    case .danceDJ: LocalizedStringResource("Dance & DJ", bundle: #bundle, comment: "Station category name.")
    case .hipHop: LocalizedStringResource("Hip Hop", bundle: #bundle, comment: "Station category name.")
    case .throwbacks: LocalizedStringResource("Throwbacks", bundle: #bundle, comment: "Station category name.")
    case .chill: LocalizedStringResource("Chill", bundle: #bundle, comment: "Station category name.")
    case .sport: LocalizedStringResource("Workout", bundle: #bundle, comment: "Station category name.")
    case .party: LocalizedStringResource("Party", bundle: #bundle, comment: "Station category name.")
    case .specials: LocalizedStringResource("Specials", bundle: #bundle, comment: "Station category name.")
    case .seasonal: LocalizedStringResource("Seasonal", bundle: #bundle, comment: "Station category name.")
    case .misc: LocalizedStringResource("Misc", bundle: #bundle, comment: "Station category name.")
    }
  }

  static func infer(from name: String) -> StationCategory {
    let normalized = name.normalizedStationKey
    if normalized.contains("dance") || normalized.contains("hardstyle") || normalized.contains("mainstage") || normalized.contains("tomorrowland") || normalized.contains("bass") {
      return .danceDJ
    }
    if normalized.contains("hiphop") || normalized.contains("rap") || normalized.contains("deutschrap") || normalized.contains("kpop") {
      return .hipHop
    }
    if normalized.contains("throwback") || normalized.contains("history") || normalized.contains("90s") || normalized.contains("greatest") || normalized.contains("rewind") || normalized.contains("2000") || normalized.contains("2010") {
      return .throwbacks
    }
    if normalized.contains("chill") || normalized.contains("sun") || normalized.contains("beach") {
      return .chill
    }
    if normalized.contains("workout") {
      return .sport
    }
    if normalized.contains("party") || normalized.contains("malle") || normalized.contains("trashpop") || normalized.contains("sugar") || normalized.contains("buffel") {
      return .party
    }
    if normalized.contains("xmas") || normalized.contains("weihnacht") || normalized.contains("alaaf") {
      return .seasonal
    }
    if normalized.contains("quiz") || normalized.contains("radio") {
      return .specials
    }
    return .popHits
  }
}

enum StreamFormatPreference: String, Codable, CaseIterable, Identifiable {
  case auto
  case aac
  case mp3

  var id: String { rawValue }
  var title: String { rawValue.uppercased() == "AUTO" ? "Auto" : rawValue.uppercased() }

  var titleResource: LocalizedStringResource {
    switch self {
    case .auto: LocalizedStringResource("Auto", bundle: #bundle, comment: "Automatic stream format option.")
    case .aac: LocalizedStringResource("AAC", bundle: #bundle, comment: "AAC audio format name; do not translate.")
    case .mp3: LocalizedStringResource("MP3", bundle: #bundle, comment: "MP3 audio format name; do not translate.")
    }
  }
}

enum StationSortPreference: String, Codable, CaseIterable, Identifiable {
  case popularity
  case alphabetical

  var id: String { rawValue }
  var title: String { rawValue == "popularity" ? "Popularity" : "Alphabetical" }

  var titleResource: LocalizedStringResource {
    switch self {
    case .popularity: LocalizedStringResource("Popularity", bundle: #bundle, comment: "Station sorting option.")
    case .alphabetical: LocalizedStringResource("Alphabetical", bundle: #bundle, comment: "Station sorting option.")
    }
  }
}

enum CatalogSource: String, Codable {
  case bundled
  case cached
  case live
  case degraded

  var title: String {
    switch self {
    case .bundled: "Bundled"
    case .cached: "Cached"
    case .live: "Live"
    case .degraded: "Offline"
    }
  }

  var helpText: String {
    switch self {
    case .bundled: "Showing bundled fallback stations. No live data yet."
    case .cached: "Showing locally cached catalog from last successful refresh."
    case .live: "Catalog and metadata are live from ilovemusic.de."
    case .degraded: "Live refresh failed — showing cached catalog. Will retry automatically."
    }
  }

  var titleResource: LocalizedStringResource {
    switch self {
    case .bundled: LocalizedStringResource("Bundled", bundle: #bundle, comment: "Bundled station catalog source status.")
    case .cached: LocalizedStringResource("Cached", bundle: #bundle, comment: "Cached station catalog source status.")
    case .live: LocalizedStringResource("Live", bundle: #bundle, comment: "Live station catalog source status.")
    case .degraded: LocalizedStringResource("Offline", bundle: #bundle, comment: "Unavailable live catalog source status.")
    }
  }

  var helpTextResource: LocalizedStringResource {
    switch self {
    case .bundled:
      LocalizedStringResource(
        "Showing bundled fallback stations. No live data yet.",
        bundle: #bundle,
        comment: "Explanation of the bundled station catalog source."
      )
    case .cached:
      LocalizedStringResource(
        "Showing locally cached catalog from last successful refresh.",
        bundle: #bundle,
        comment: "Explanation of the cached station catalog source."
      )
    case .live:
      LocalizedStringResource(
        "Catalog and metadata are live from ilovemusic.de.",
        bundle: #bundle,
        comment: "Explanation of the live station catalog source."
      )
    case .degraded:
      LocalizedStringResource(
        "Live refresh failed — showing cached catalog. Will retry automatically.",
        bundle: #bundle,
        comment: "Explanation shown when live catalog refresh failed."
      )
    }
  }
}

enum RefreshState: Equatable {
  case idle
  case refreshing
  case degraded(String)
}

enum RefreshOutcome: Equatable {
  case idle
  case refreshing
  case success
  case failed
}

struct Station: Codable, Identifiable, Hashable {
  var id: String
  var remoteID: String
  var name: String
  var slug: String
  var category: StationCategory
  var accentHex: String
  var aacStreamURLString: String?
  var mp3StreamURLString: String?
  var m3uURLString: String?
  var websiteURLString: String
  var iconURLString: String?
  var tagline: String
  var featured: Bool
  var listenerCount: Int?

  var artworkURL: URL? { iconURLString.flatMap(URL.init(string:)) }
  var displayName: String { Self.normalizeDisplayName(name) }

  static func normalizeDisplayName(_ raw: String) -> String {
    raw
      .replacingOccurrences(of: #"(?i)\bI\s*LOVE\b"#, with: "I ♥", options: .regularExpression)
      .replacingOccurrences(of: #"(?i)\bILOVE\b"#, with: "I ♥", options: .regularExpression)
      .replacingOccurrences(of: #"(?i)\bI\s*HERZ\b"#, with: "I ♥", options: .regularExpression)
      .replacingOccurrences(of: #"(?i)\bIHERZ\b"#, with: "I ♥", options: .regularExpression)
      .replacingOccurrences(of: #"\s*♥\s*"#, with: " ♥ ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func strippedBrandName(_ raw: String) -> String {
    normalizeDisplayName(raw)
      .replacingOccurrences(of: #"^I\s+♥\s+"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct NowPlaying: Codable, Hashable {
  var stationID: String
  var artist: String
  var title: String
  var artworkURLString: String?
  var updatedAt: Date

  var displayLine: String {
    if artist.isEmpty { return title }
    if title.isEmpty { return artist }
    return "\(artist) • \(title)"
  }
}

enum PlaybackPhase: String, Codable {
  case idle
  case buffering
  case playing
  case paused
  case reconnecting
  case failed

  var title: String {
    switch self {
    case .idle: "Ready"
    case .buffering: "Buffering"
    case .playing: "Playing"
    case .paused: "Paused"
    case .reconnecting: "Reconnecting"
    case .failed: "Failed"
    }
  }

  var titleResource: LocalizedStringResource {
    switch self {
    case .idle: LocalizedStringResource("Ready", bundle: #bundle, comment: "Playback status.")
    case .buffering: LocalizedStringResource("Buffering", bundle: #bundle, comment: "Playback status.")
    case .playing: LocalizedStringResource("Playing", bundle: #bundle, comment: "Playback status.")
    case .paused: LocalizedStringResource("Paused", bundle: #bundle, comment: "Playback status.")
    case .reconnecting: LocalizedStringResource("Reconnecting", bundle: #bundle, comment: "Playback status.")
    case .failed: LocalizedStringResource("Failed", bundle: #bundle, comment: "Playback status.")
    }
  }
}

struct PlaybackState: Codable, Equatable {
  var stationID: String?
  var phase: PlaybackPhase
  var resolvedStreamURLString: String?
  var errorMessage: String?
  var streamKind: String?

  static let idle = PlaybackState(
    stationID: nil,
    phase: .idle,
    resolvedStreamURLString: nil,
    errorMessage: nil,
    streamKind: nil
  )
}

struct UserPreferences: Codable, Equatable {
  var favoriteIDs: [String]
  var lastStationID: String?
  var volume: Double
  var muted: Bool?
  var preferredStreamFormat: StreamFormatPreference
  var stationSort: StationSortPreference
  var launchAtLogin: Bool
  var globalHotkeysEnabled: Bool
  var resumeLastStationOnLaunch: Bool
  var recordHistoryEnabled: Bool?
  // Optional so state files written before localization continue to decode.
  var appLanguage: AppLanguage?

  // Discord Rich Presence (optional for backwards-compatible decode of old state.json)
  var discordEnabled: Bool?
  var discordClientID: String?
  var discordShowArtwork: Bool?
  var discordShowButton: Bool?
  var discordShowListeners: Bool?
  var discordShowStationLogo: Bool?

  // When false (default), output volume is capped below full power so the
  // slider's usable range spreads out for low-level listening. Unlock to
  // restore full output. Optional for backwards-compatible decode.
  var unlockMaxVolume: Bool?

  // Per-action global hotkeys. Optional so old state.json files (or users who
  // explicitly cleared a slot) decode cleanly; `nil` means "unassigned".
  var hotkeyPlayPause: HotkeyBinding?
  var hotkeyNextStation: HotkeyBinding?
  var hotkeyRandomStation: HotkeyBinding?
  var hotkeyQuit: HotkeyBinding?

  static let `default` = UserPreferences(
    favoriteIDs: [],
    lastStationID: nil,
    volume: 0.70,
    muted: false,
    preferredStreamFormat: .auto,
    stationSort: .popularity,
    launchAtLogin: false,
    globalHotkeysEnabled: true,
    resumeLastStationOnLaunch: true,
    recordHistoryEnabled: true,
    appLanguage: .system,
    discordEnabled: false,
    discordClientID: nil,
    discordShowArtwork: true,
    discordShowButton: true,
    discordShowListeners: true,
    discordShowStationLogo: true,
    unlockMaxVolume: false,
    hotkeyPlayPause: .defaultBinding(for: .playPause),
    hotkeyNextStation: .defaultBinding(for: .nextStation),
    hotkeyRandomStation: .defaultBinding(for: .randomStation),
    hotkeyQuit: .defaultBinding(for: .quit)
  )

  var effectiveAppLanguage: AppLanguage { appLanguage ?? .system }

  /// Resolves the four hotkey slots into a dictionary, falling back to the
  /// built-in default if the user hasn't customized one. A slot the user
  /// explicitly cleared (set to `nil` via the recorder UI) stays absent here.
  var hotkeyBindings: HotkeyBindings {
    var result: HotkeyBindings = [:]
    if let binding = hotkeyPlayPause { result[.playPause] = binding }
    if let binding = hotkeyNextStation { result[.nextStation] = binding }
    if let binding = hotkeyRandomStation { result[.randomStation] = binding }
    if let binding = hotkeyQuit { result[.quit] = binding }
    return result
  }

  func hotkeyBinding(for id: HotkeyID) -> HotkeyBinding? {
    switch id {
    case .playPause: return hotkeyPlayPause
    case .nextStation: return hotkeyNextStation
    case .randomStation: return hotkeyRandomStation
    case .quit: return hotkeyQuit
    }
  }

  mutating func setHotkeyBinding(_ binding: HotkeyBinding?, for id: HotkeyID) {
    switch id {
    case .playPause: hotkeyPlayPause = binding
    case .nextStation: hotkeyNextStation = binding
    case .randomStation: hotkeyRandomStation = binding
    case .quit: hotkeyQuit = binding
    }
  }
}

struct PlaybackHistoryEntry: Codable, Hashable, Identifiable {
  var stationID: String
  var playedAt: Date
  var id: String { "\(stationID)-\(playedAt.timeIntervalSince1970)" }
}

struct PersistedAppState: Codable {
  var preferences: UserPreferences
  var history: [PlaybackHistoryEntry]
  var cachedStations: [Station]
  var cachedNowPlaying: [String: NowPlaying]
  var lastRefreshAt: Date?
  var source: CatalogSource
  var songHistoryByStationID: [String: [NowPlaying]]?

  static let `default` = PersistedAppState(
    preferences: .default,
    history: [],
    cachedStations: [],
    cachedNowPlaying: [:],
    lastRefreshAt: nil,
    source: .bundled,
    songHistoryByStationID: [:]
  )
}

struct CatalogSnapshot {
  var stations: [Station]
  var playlistEntries: [String: NowPlaying]
  var source: CatalogSource
  var updatedAt: Date
  var rawStationCount: Int
  var filteredOutCount: Int
}

struct DiagnosticsSnapshot {
  var rawStationCount: Int
  var visibleStationCount: Int
  var filteredOutCount: Int
  var lastCatalogRefreshAt: Date?
  var lastMetadataRefreshAt: Date?
  var lastArtworkCacheClearAt: Date?
  var source: CatalogSource
  var activeStreamKind: String?
  var activeStationName: String?

  static let empty = DiagnosticsSnapshot(
    rawStationCount: 0,
    visibleStationCount: 0,
    filteredOutCount: 0,
    lastCatalogRefreshAt: nil,
    lastMetadataRefreshAt: nil,
    lastArtworkCacheClearAt: nil,
    source: .bundled,
    activeStreamKind: nil,
    activeStationName: nil
  )
}

struct VisibilityPolicy: Codable {
  var hiddenRemoteIDs: [String]
}

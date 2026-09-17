import Foundation
import Observation
import os
import SwiftUI

@MainActor
@Observable
final class AppModel {
  private static let defaultDiscordSessionGracePeriod: Duration = .seconds(30)
  @ObservationIgnored private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppModel")

  private(set) var stations: [Station] = [] {
    didSet { recomputeVisibleStations() }
  }
  private(set) var metadataByStationID: [String: NowPlaying] = [:]
  private(set) var songHistoryByStationID: [String: [NowPlaying]] = [:]
  private(set) var liveRecentSongsByStationID: [String: [NowPlaying]] = [:]
  private(set) var preferences: UserPreferences
  /// Language captured from persisted preferences at launch. It intentionally
  /// stays unchanged until the process restarts.
  private(set) var activeLanguage: AppLanguage
  private(set) var history: [PlaybackHistoryEntry]
  private(set) var historyRecorder: PlayHistoryRecorder
  private(set) var diagnostics = DiagnosticsSnapshot.empty
  private(set) var controlConnectionLog: [ControlLogEntry]
  private(set) var controlRuntimeStatus: ControlServerRuntimeStatus = .empty
  private(set) var statsSnapshotRevision = 0
  private(set) var discordConnectionLog: [ControlLogEntry]
  private(set) var refreshState: RefreshState = .idle
  private(set) var refreshOutcome: RefreshOutcome = .idle
  private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .off
  /// Hotkey slots the system refused to register, usually because macOS or
  /// another app already owns the combo.
  private(set) var hotkeyConflicts: Set<HotkeyID> = []
  private(set) var lastRefreshAt: Date?
  private(set) var source: CatalogSource = .bundled
  var activeStationID: String?
  @ObservationIgnored private(set) var channelStartedAt: Date?

  private let historyLength = 5
  private let liveRecentSongsTTL: TimeInterval = 5 * 60

  @ObservationIgnored private let refreshSerializer = RefreshSerializer()
  @ObservationIgnored private let playbackController: PlaybackController
  @ObservationIgnored private let stateStore: AppStateStore
  @ObservationIgnored private let seedRepository: SeedRepository
  @ObservationIgnored private let catalogRepository: CatalogRepository
  @ObservationIgnored let controlDiagnosticsStore: ControlDiagnosticsStore
  @ObservationIgnored let discordDiagnosticsStore: DiscordDiagnosticsStore
  @ObservationIgnored private let preferencesCoordinator = PreferencesCoordinator()
  @ObservationIgnored private let refreshCoordinator: LibraryRefreshCoordinator
  let discordManager: DiscordRichPresenceManager
  @ObservationIgnored private var discordSessionResetTask: Task<Void, Never>?
  @ObservationIgnored private var liveRecentFetchTasks: [String: Task<[NowPlaying], Never>] = [:]
  @ObservationIgnored private var liveRecentFetchedAtByStationID: [String: Date] = [:]
  @ObservationIgnored private var liveRecentMetadataSignatureByStationID: [String: String] = [:]
  @ObservationIgnored private var bootstrapped = false
  @ObservationIgnored private let statsProvider = StatsSnapshotProvider()
  @ObservationIgnored var requestOpenHistoryWindow: (() -> Void)?
  @ObservationIgnored var requestOpenSettingsWindow: (() -> Void)?
  @ObservationIgnored private let discordSessionGracePeriod: Duration

  init(
    playbackController: PlaybackController,
    discordSessionGracePeriod: Duration = AppModel.defaultDiscordSessionGracePeriod,
    refreshCadence: LibraryRefreshCoordinator.Cadence = .production,
    stateStoreOverride: AppStateStore? = nil
  ) {
    self.playbackController = playbackController
    self.discordSessionGracePeriod = discordSessionGracePeriod
    self.discordManager = DiscordRichPresenceManager()
    self.stateStore = stateStoreOverride ?? AppStateStore()
    self.seedRepository = SeedRepository()
    self.historyRecorder = PlayHistoryRecorder(store: PlayHistoryStore())
    self.controlDiagnosticsStore = ControlDiagnosticsStore()
    self.discordDiagnosticsStore = DiscordDiagnosticsStore()
    self.refreshCoordinator = LibraryRefreshCoordinator(cadence: refreshCadence)
    self.catalogRepository = CatalogRepository(
      apiClient: ILoveMusicAPIClient(),
      seedRepository: seedRepository,
      stateStore: self.stateStore
    )

    let persisted = self.stateStore.load()
    preferences = persisted.preferences
    activeLanguage = persisted.preferences.effectiveAppLanguage
    history = persisted.history
    metadataByStationID = persisted.cachedNowPlaying
    songHistoryByStationID = persisted.songHistoryByStationID ?? [:]
    lastRefreshAt = persisted.lastRefreshAt
    source = persisted.source
    controlConnectionLog = controlDiagnosticsStore.load()
    discordConnectionLog = discordDiagnosticsStore.load()

    discordManager.configureDiagnostics { [weak self] area, severity, message in
      self?.discordDiagnosticsStore.append(area: area, severity: severity, message: message)
    }

    playbackController.restoreVolume(
      volume: preferences.volume,
      muted: preferences.muted ?? false
    )
    playbackController.setMaxVolumeUnlocked(preferences.unlockMaxVolume ?? false)
    playbackController.onPlayRequested = { [weak self] in
      guard let self, let station = self.activeStation else { return }
      await self.play(station)
    }
    playbackController.onNextRequested = { [weak self] in
      guard let self else { return }
      await self.playNextStation()
    }
    playbackController.onPlaybackStateChanged = { [weak self] state in
      guard let self else { return }
      Task { @MainActor in
        self.updateDiscordSession(for: state)
        self.historyRecorder.refresh(
          station: self.activeStation,
          metadata: self.activeMetadata,
          state: state
        )
        self.syncSystemNowPlaying()
        self.diagnostics = self.buildDiagnostics(
          rawStationCount: self.diagnostics.rawStationCount,
          filteredOutCount: self.diagnostics.filteredOutCount
        )
        self.pushDiscordPresence()
        self.persist()
      }
    }
    historyRecorder.bootstrap()
    historyRecorder.attach(appModel: self, playbackController: playbackController)
    historyRecorder.onEventsChanged = { [weak self] in
      self?.invalidateStatsSnapshot()
    }
    controlDiagnosticsStore.onChange = { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.controlConnectionLog = self.controlDiagnosticsStore.load()
      }
    }
    discordDiagnosticsStore.onChange = { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.discordConnectionLog = self.discordDiagnosticsStore.load()
      }
    }
  }

  deinit {
    // refreshCoordinator's own deinit cancels its tasks when AppModel
    // releases the last reference; nothing else to do here.
    discordSessionResetTask?.cancel()
  }

  var activeStation: Station? {
    stations.first(where: { $0.id == activeStationID })
  }

  var activeMetadata: NowPlaying? {
    guard let activeStationID else { return nil }
    return metadataByStationID[activeStationID]
  }

  var activePlaybackPhase: PlaybackPhase {
    playbackController.state.phase
  }

  var activeVolumePercent: Int {
    playbackController.volumePercent
  }

  var isVolumeMuted: Bool {
    playbackController.isMuted
  }

  var favoriteStations: [Station] {
    visibleStations.filter { preferences.favoriteIDs.contains($0.id) }
  }

  var channelStations: [Station] {
    let favoriteIDs = Set(preferences.favoriteIDs)
    return visibleStations.filter { !favoriteIDs.contains($0.id) }
  }

  /// Cached sorted station list. Sorting (with `localizedCaseInsensitiveCompare`)
  /// is expensive and the menu-bar popover reads `favoriteStations` and
  /// `channelStations` — each previously re-sorted on every body render. The
  /// result only changes when the station set, favorites, or sort order change,
  /// so we recompute on those mutations instead of per access.
  private(set) var visibleStations: [Station] = []

  private func recomputeVisibleStations() {
    let favoriteIDs = Set(preferences.favoriteIDs)
    visibleStations = stations.sorted { left, right in
      if favoriteIDs.contains(left.id) != favoriteIDs.contains(right.id) {
        return favoriteIDs.contains(left.id) && !favoriteIDs.contains(right.id)
      }

      switch preferences.stationSort {
      case .popularity:
        let leftListeners = left.listenerCount ?? 0
        let rightListeners = right.listenerCount ?? 0
        if leftListeners != rightListeners {
          return leftListeners > rightListeners
        }
      case .alphabetical:
        break
      }

      return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }
  }

  var menuBarLabel: String {
    if let activeStation {
      return activeStation.name
    }
    return AppIdentity.menuBarFallbackLabel
  }

  func bootstrapIfNeeded() async {
    guard !bootstrapped else { return }
    bootstrapped = true
    logger.notice("bootstrap: begin")

    applyLaunchAtLoginPreference()
    applyGlobalHotkeys()

    if preferences.discordEnabled == true {
      discordManager.configure(clientID: preferences.discordClientID, showButton: preferences.discordShowButton ?? true)
      discordManager.start()
    }

    historyRecorder.setEnabled(preferences.recordHistoryEnabled ?? true)

    let snapshot = await catalogRepository.bootstrapCatalog()
    stations = snapshot.stations
    source = snapshot.source
    lastRefreshAt = snapshot.updatedAt
    logger.notice("bootstrap: source=\(snapshot.source.rawValue, privacy: .public) stations=\(snapshot.stations.count, privacy: .public) raw=\(snapshot.rawStationCount, privacy: .public)")

    if preferences.resumeLastStationOnLaunch,
       let lastID = preferences.lastStationID,
       stations.contains(where: { $0.id == lastID }) {
      activeStationID = lastID
      logger.info("bootstrap: resumed last station id=\(lastID, privacy: .public)")
    } else {
      activeStationID = stations.first?.id
      if let id = activeStationID {
        logger.info("bootstrap: selected default station id=\(id, privacy: .public)")
      } else {
        logger.warning("bootstrap: no station available")
      }
    }

    diagnostics = buildDiagnostics(rawStationCount: snapshot.rawStationCount, filteredOutCount: snapshot.filteredOutCount)
    historyRecorder.refresh(station: activeStation, metadata: activeMetadata, state: playbackController.state)
    syncSystemNowPlaying()
    persist()
    startBackgroundLoops()
    await refreshCatalog(userInitiated: false)
    logger.notice("bootstrap: complete")
  }

  @discardableResult
  func refreshCatalog(userInitiated: Bool) async -> Bool {
    await refreshSerializer.run { [weak self] in
      guard let self else { return false }
      return await self.performRefreshCatalog(userInitiated: userInitiated)
    }
  }

  private func performRefreshCatalog(userInitiated: Bool) async -> Bool {
    let previousSource = source
    let started = Date()
    refreshState = .refreshing
    let snapshot = await catalogRepository.refreshCatalog()
    let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)

    stations = snapshot.stations
    source = snapshot.source
    lastRefreshAt = snapshot.updatedAt
    diagnostics = buildDiagnostics(rawStationCount: snapshot.rawStationCount, filteredOutCount: snapshot.filteredOutCount)

    let activeIDs = Set(stations.map(\.id))
    if let activeStationID, !activeIDs.contains(activeStationID) {
      self.activeStationID = stations.first?.id
    } else if self.activeStationID == nil {
      self.activeStationID = stations.first?.id
    }

    if !snapshot.playlistEntries.isEmpty {
      metadataByStationID = snapshot.playlistEntries
    }

    refreshState = source == .degraded ? .degraded("Using cached catalog") : .idle
    historyRecorder.refresh(station: activeStation, metadata: activeMetadata, state: playbackController.state)
    invalidateStatsSnapshot()
    syncSystemNowPlaying()
    persist()

    let initiator = userInitiated ? "user" : "auto"
    if previousSource != snapshot.source {
      logger.notice("refreshCatalog: \(initiator, privacy: .public) source=\(previousSource.rawValue, privacy: .public)→\(snapshot.source.rawValue, privacy: .public) stations=\(snapshot.stations.count, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public)")
    } else {
      logger.info("refreshCatalog: \(initiator, privacy: .public) source=\(snapshot.source.rawValue, privacy: .public) stations=\(snapshot.stations.count, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public)")
    }
    if snapshot.source == .degraded {
      logger.warning("refreshCatalog: live fetch failed, serving cached/seed catalog")
    }

    return snapshot.source == .live
  }

  func refreshListeners() async {
    await refreshSerializer.run { [weak self] in
      await self?.performRefreshListeners()
    }
  }

  private func performRefreshListeners() async {
    stations = await catalogRepository.refreshListeners(currentStations: stations)
    diagnostics = buildDiagnostics(rawStationCount: diagnostics.rawStationCount, filteredOutCount: diagnostics.filteredOutCount)
    persist()
  }

  func refreshMetadata() async {
    await refreshSerializer.run { [weak self] in
      await self?.performRefreshMetadata()
    }
  }

  private func performRefreshMetadata() async {
    guard !stations.isEmpty else { return }
    let currentMetadata = await catalogRepository.refreshMetadata(currentStations: stations)
    guard !currentMetadata.isEmpty else { return }

    for (stationID, newEntry) in currentMetadata {
      let prev = metadataByStationID[stationID]
      let sameTrack = prev.map { $0.title == newEntry.title && $0.artist == newEntry.artist } ?? false

      var stored = newEntry
      if sameTrack, let prev {
        stored.updatedAt = prev.updatedAt
      }
      // Only mutate the observable dictionary when the entry actually changed.
      // refreshMetadata runs for every station every 30s; blindly reassigning
      // unchanged entries triggers needless SwiftUI invalidation across the
      // whole station list.
      if prev != stored {
        metadataByStationID[stationID] = stored
      }

      if !sameTrack, let prev, !(prev.title.isEmpty && prev.artist.isEmpty) {
        var hist = songHistoryByStationID[stationID] ?? []
        hist.removeAll { $0.title == prev.title && $0.artist == prev.artist }
        hist.insert(prev, at: 0)
        songHistoryByStationID[stationID] = Array(hist.prefix(historyLength))
      }
    }
    diagnostics.lastMetadataRefreshAt = .now
    historyRecorder.refresh(station: activeStation, metadata: activeMetadata, state: playbackController.state)
    syncSystemNowPlaying()
    pushDiscordPresence()
    persist()
  }

  func refreshAll() async {
    guard refreshOutcome != .refreshing else { return }
    refreshState = .refreshing
    refreshOutcome = .refreshing
    let started = Date()

    // Catalog must complete first so listener/metadata refreshes operate on
    // the up-to-date station set. See `LibraryRefreshPipeline`.
    logger.notice("refreshAll: begin")
    let pipeline = LibraryRefreshPipeline(
      refreshCatalog: { [weak self] in
        guard let self else { return false }
        return await self.refreshCatalog(userInitiated: true)
      },
      refreshListeners: { [weak self] in
        await self?.refreshListeners()
      },
      refreshMetadata: { [weak self] in
        await self?.refreshMetadata()
      }
    )
    let success = await pipeline.run()
    let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
    logger.notice("refreshAll: end success=\(success, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public)")

    let minSpin: TimeInterval = 0.6
    let elapsed = Date().timeIntervalSince(started)
    if elapsed < minSpin {
      try? await Task.sleep(for: .seconds(minSpin - elapsed))
    }

    refreshState = .idle
    refreshOutcome = success ? .success : .failed

    let outcomeAtFlash = refreshOutcome
    try? await Task.sleep(for: .milliseconds(1200))
    if refreshOutcome == outcomeAtFlash {
      refreshOutcome = .idle
    }
  }

  func songHistory(for stationID: String) -> [NowPlaying] {
    songHistoryByStationID[stationID] ?? []
  }

  func stationRecentSongs(for station: Station) -> [NowPlaying] {
    let preferred = liveRecentSongsByStationID[station.id] ?? songHistoryByStationID[station.id] ?? []
    return normalizedRecentSongs(preferred, stationID: station.id)
  }

  func recentSongsTaskID(for station: Station) -> String {
    let metadata = metadataByStationID[station.id]
    return [
      station.id,
      metadata?.artist ?? "",
      metadata?.title ?? ""
    ].joined(separator: "|")
  }

  func loadRecentSongsIfNeeded(for station: Station, force: Bool = false) async {
    let currentSignature = trackSignature(for: metadataByStationID[station.id])

    if !force,
       let fetchedAt = liveRecentFetchedAtByStationID[station.id],
       Date().timeIntervalSince(fetchedAt) < liveRecentSongsTTL,
       liveRecentMetadataSignatureByStationID[station.id] == currentSignature {
      return
    }

    if let task = liveRecentFetchTasks[station.id] {
      let tracks = await task.value
      applyRecentSongs(tracks, for: station.id, metadataSignature: currentSignature)
      return
    }

    let task = Task { [catalogRepository] in
      await catalogRepository.fetchRecentTracks(for: station)
    }
    liveRecentFetchTasks[station.id] = task

    let tracks = await task.value
    liveRecentFetchTasks[station.id] = nil
    applyRecentSongs(tracks, for: station.id, metadataSignature: currentSignature)
  }

  func play(_ station: Station) async {
    if activeStationID != station.id {
      historyRecorder.closeOpenEvent(reason: .stationChanged)
    }
    activeStationID = station.id
    preferences.lastStationID = station.id
    recordHistory(for: station.id)
    syncSystemNowPlaying()
    pushDiscordPresence()
    await playbackController.play(station: station)
    persist()
  }

  func togglePlayback() async {
    switch playbackController.state.phase {
    case .playing, .buffering, .reconnecting:
      playbackController.pause()
    case .paused:
      playbackController.resume()
    case .idle, .failed:
      if let activeStation {
        await play(activeStation)
      }
    }
  }

  func playNextStation() async {
    guard !visibleStations.isEmpty else { return }
    let currentIndex = visibleStations.firstIndex(where: { $0.id == activeStationID }) ?? -1
    let next = visibleStations[(currentIndex + 1 + visibleStations.count) % visibleStations.count]
    await play(next)
  }

  @discardableResult
  func playRandomStation(favoritesOnly: Bool = false) async -> Bool {
    let basePool = favoritesOnly ? favoriteStations : visibleStations
    let pool = basePool.filter { $0.id != activeStationID }
    guard let pick = pool.randomElement() ?? basePool.randomElement() else { return false }
    await play(pick)
    return true
  }

  func toggleFavorite(_ stationID: String) {
    if preferences.favoriteIDs.contains(stationID) {
      preferences.favoriteIDs.removeAll { $0 == stationID }
    } else {
      preferences.favoriteIDs.append(stationID)
      preferences.favoriteIDs.sort()
    }
    recomputeVisibleStations()
    persist()
  }

  func metadata(for station: Station) -> NowPlaying? {
    metadataByStationID[station.id]
  }

  func updateVolume(_ value: Double) {
    playbackController.setVolume(value)
    syncVolumePreferencesFromPlaybackController()
    persist()
  }

  func updateVolumePercent(_ value: Int) {
    playbackController.setVolumePercent(value)
    syncVolumePreferencesFromPlaybackController()
    persist()
  }

  func stepVolume(_ delta: Int) {
    playbackController.stepVolume(by: delta)
    syncVolumePreferencesFromPlaybackController()
    persist()
  }

  func updateUnlockMaxVolume(_ value: Bool) {
    preferences.unlockMaxVolume = value
    playbackController.setMaxVolumeUnlocked(value)
    persist()
  }

  func toggleMute() {
    playbackController.toggleMute()
    syncVolumePreferencesFromPlaybackController()
    persist()
  }

  func setMuted(_ muted: Bool) {
    playbackController.setMuted(muted)
    syncVolumePreferencesFromPlaybackController()
    persist()
  }

  func updateStationSort(_ value: StationSortPreference) {
    preferences.stationSort = value
    recomputeVisibleStations()
    persist()
  }

  func updateAppLanguage(_ value: AppLanguage) {
    preferences.appLanguage = value
    persist()
  }

  var requiresLanguageRestart: Bool {
    preferences.effectiveAppLanguage != activeLanguage
  }

  func updateLaunchAtLogin(_ value: Bool) {
    preferences.launchAtLogin = value
    applyLaunchAtLoginPreference()
    persist()
  }

  func updateGlobalHotkeysEnabled(_ value: Bool) {
    preferences.globalHotkeysEnabled = value
    applyGlobalHotkeys()
    persist()
  }

  /// Writes a single hotkey slot and re-applies the full binding set if
  /// hotkeys are currently enabled. Callers (settings UI) are expected to
  /// suspend the Carbon registration while recording so the new combo never
  /// clashes with an existing one mid-input.
  func updateHotkey(_ id: HotkeyID, binding: HotkeyBinding?) {
    preferences.setHotkeyBinding(binding, for: id)
    applyGlobalHotkeys()
    persist()
  }

  /// Releases the Carbon hotkeys so a `HotkeyRecorderRow` can read raw
  /// `NSEvent` key-down events without one of the registered combos firing.
  func suspendGlobalHotkeysForRecording() {
    preferencesCoordinator.suspendGlobalHotkeys()
  }

  /// Re-applies the persisted hotkey bindings — usually called after a
  /// recording session exits or is cancelled.
  func resumeGlobalHotkeys() {
    applyGlobalHotkeys()
  }

  func updateResumeLastStation(_ value: Bool) {
    preferences.resumeLastStationOnLaunch = value
    persist()
  }

  func updateRecordHistoryEnabled(_ value: Bool) {
    preferences.recordHistoryEnabled = value
    historyRecorder.setEnabled(value)
    persist()
  }

  func resetListeningHistory() {
    historyRecorder.reset()
    invalidateStatsSnapshot()
    persist()
  }

  /// Auxiliary windows (Settings, History) briefly need `.regular` policy
  /// for focus and ordering. The app itself stays menu-bar-only (`.accessory`,
  /// no Dock icon) and always flips back once no regular window is visible.
  func prepareForAuxiliaryWindowPresentation() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func restoreAccessoryPolicyIfNeeded() {
    let hasVisibleRegularWindow = NSApp.windows.contains {
      $0.isVisible && ($0.canBecomeMain || $0.canBecomeKey)
    }
    if !hasVisibleRegularWindow {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  var statsSnapshotComputeCount: Int { statsProvider.computeCount }

  func statsSnapshot(
    for window: HistoryWindow,
    now: Date = .now,
    calendar: Calendar = .current
  ) -> StatsSnapshot {
    // Reading the revision here makes cache invalidation visible to SwiftUI
    // even when the provider returns a cached snapshot without reading events.
    _ = statsSnapshotRevision
    let events = historyRecorder.events
    let stationLookup = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
    return statsProvider.snapshot(for: window, now: now, calendar: calendar) {
      PlayHistoryStats.snapshot(
        events: events,
        window: window,
        stationLookup: stationLookup,
        now: now,
        calendar: calendar
      )
    }
  }

  func updateDiscordEnabled(_ value: Bool) {
    preferences.discordEnabled = value
    if value {
      discordManager.configure(clientID: preferences.discordClientID, showButton: preferences.discordShowButton ?? true)
      discordManager.start()
      pushDiscordPresence()
    } else {
      discordManager.stop()
    }
    persist()
  }

  func updateDiscordClientID(_ value: String) {
    preferences.discordClientID = value.trimmingCharacters(in: .whitespaces)
    discordManager.configure(clientID: preferences.discordClientID, showButton: preferences.discordShowButton ?? true)
    if preferences.discordEnabled == true {
      discordManager.stop()
      discordManager.start()
      pushDiscordPresence()
    }
    persist()
  }

  func updateDiscordShowArtwork(_ value: Bool) {
    preferences.discordShowArtwork = value
    pushDiscordPresence()
    persist()
  }

  func updateDiscordShowButton(_ value: Bool) {
    preferences.discordShowButton = value
    discordManager.configure(clientID: preferences.discordClientID, showButton: value)
    pushDiscordPresence()
    persist()
  }

  func updateDiscordShowListeners(_ value: Bool) {
    preferences.discordShowListeners = value
    pushDiscordPresence()
    persist()
  }

  func updateDiscordShowStationLogo(_ value: Bool) {
    preferences.discordShowStationLogo = value
    pushDiscordPresence()
    persist()
  }

  private func pushDiscordPresence() {
    guard preferences.discordEnabled == true else { return }

    guard channelStartedAt != nil else {
      discordManager.clear()
      return
    }

    guard let stationID = activeStationID, let station = stations.first(where: { $0.id == stationID }) else {
      discordManager.clear()
      return
    }

    var payload = DiscordRichPresenceManager.PresencePayload()
    payload.stationName = station.displayName
    payload.showStationLogo = preferences.discordShowStationLogo ?? true
    payload.websiteURL = URL(string: station.websiteURLString)
    payload.startedAt = channelStartedAt
    if preferences.discordShowListeners ?? true,
       let listenerCount = station.listenerCount,
       listenerCount > 0 {
      payload.listenerCount = listenerCount
    }

    if let md = metadata(for: station) {
      payload.artist = md.artist
      payload.title = md.title
      if preferences.discordShowArtwork ?? true, let urlString = md.artworkURLString {
        payload.artworkURL = URL(string: urlString)
      }
    } else if preferences.discordShowArtwork ?? true, let urlString = station.iconURLString {
      // Fallback to station icon if no song artwork
      payload.artworkURL = URL(string: urlString)
    }
    
    discordManager.update(payload)
  }

  private func updateDiscordSession(for state: PlaybackState) {
    switch state.phase {
    case .playing:
      discordSessionResetTask?.cancel()
      discordSessionResetTask = nil
      if channelStartedAt == nil {
        channelStartedAt = .now
      }

    case .buffering, .reconnecting:
      discordSessionResetTask?.cancel()
      discordSessionResetTask = nil

    case .paused, .idle, .failed:
      scheduleDiscordSessionReset()
    }
  }

  private func scheduleDiscordSessionReset() {
    guard channelStartedAt != nil else { return }

    discordSessionResetTask?.cancel()
    discordSessionResetTask = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: self.discordSessionGracePeriod)
      guard !Task.isCancelled else { return }

      await MainActor.run {
        guard self.playbackController.state.phase != .playing,
              self.playbackController.state.phase != .buffering,
              self.playbackController.state.phase != .reconnecting else {
          self.discordSessionResetTask = nil
          return
        }

        self.channelStartedAt = nil
        self.discordSessionResetTask = nil
        self.pushDiscordPresence()
      }
    }
  }

  private func resetDiscordSession() {
    discordSessionResetTask?.cancel()
    discordSessionResetTask = nil
    channelStartedAt = nil
  }

  func clearCachedCatalog() async {
    stateStore.clearCatalogCache()
    let snapshot = await catalogRepository.bootstrapCatalog(forceSeedOnly: true)
    stations = snapshot.stations
    metadataByStationID = [:]
    source = snapshot.source
    lastRefreshAt = snapshot.updatedAt
    diagnostics = buildDiagnostics(rawStationCount: snapshot.rawStationCount, filteredOutCount: snapshot.filteredOutCount)
    syncSystemNowPlaying()
    persist()
  }

  func clearCachedArtwork() {
    URLCache.shared.removeAllCachedResponses()
    diagnostics.lastArtworkCacheClearAt = .now
    persist()
  }

  func clearControlConnectionLog() {
    controlDiagnosticsStore.clear()
    controlConnectionLog = []
  }

  func updateControlRuntimeStatus(_ status: ControlServerRuntimeStatus) {
    controlRuntimeStatus = status
  }

  func clearDiscordConnectionLog() {
    discordDiagnosticsStore.clear()
    discordConnectionLog = []
  }

  func flushPendingPersistence() {
    stateStore.flushPendingWrites()
    controlDiagnosticsStore.flush()
    discordDiagnosticsStore.flush()
  }

  private func startBackgroundLoops() {
    refreshCoordinator.start(
      refreshCatalog: { [weak self] in
        await self?.refreshCatalog(userInitiated: false)
      },
      refreshListeners: { [weak self] in
        await self?.refreshListeners()
      },
      refreshMetadata: { [weak self] in
        await self?.refreshMetadata()
      }
    )

    preferencesCoordinator.setHotkeyHandlers(
      onTogglePlayback: { [weak self] in
        guard let self else { return }
        Task { await self.togglePlayback() }
      },
      onNextStation: { [weak self] in
        guard let self else { return }
        Task { await self.playNextStation() }
      },
      onShuffleStation: { [weak self] in
        guard let self else { return }
        Task { await self.playRandomStation() }
      },
      onQuit: {
        Task { @MainActor in NSApplication.shared.terminate(nil) }
      }
    )
  }

  private func recordHistory(for stationID: String) {
    history.insert(PlaybackHistoryEntry(stationID: stationID, playedAt: .now), at: 0)
    var seen = Set<String>()
    history = history.filter { seen.insert($0.stationID).inserted }.prefix(20).map { $0 }
  }

  private func applyLaunchAtLoginPreference() {
    switch preferencesCoordinator.applyLaunchAtLogin(preferences.launchAtLogin) {
    case .applied:
      launchAtLoginStatus = preferences.launchAtLogin ? .enabled : .off
    case .unavailable:
      launchAtLoginStatus = .unavailable
    case .failed(let reason):
      // Keeping the preference on would claim a login item that macOS never
      // registered, so fall back to what the system actually has.
      preferences.launchAtLogin = preferencesCoordinator.isLaunchAtLoginRegistered
      launchAtLoginStatus = .failed(reason: reason)
      logger.error("launch at login failed: \(reason, privacy: .public)")
    }
  }

  private func applyGlobalHotkeys() {
    hotkeyConflicts = preferencesCoordinator.applyHotkeyBindings(
      enabled: preferences.globalHotkeysEnabled,
      bindings: preferences.hotkeyBindings
    )
    if !hotkeyConflicts.isEmpty {
      let names = hotkeyConflicts.map(\.title).sorted().joined(separator: ", ")
      logger.notice("hotkeys rejected by the system: \(names, privacy: .public)")
    }
  }

  private func buildDiagnostics(rawStationCount: Int, filteredOutCount: Int) -> DiagnosticsSnapshot {
    DiagnosticsSnapshot(
      rawStationCount: rawStationCount,
      visibleStationCount: stations.count,
      filteredOutCount: filteredOutCount,
      lastCatalogRefreshAt: lastRefreshAt,
      lastMetadataRefreshAt: diagnostics.lastMetadataRefreshAt,
      lastArtworkCacheClearAt: diagnostics.lastArtworkCacheClearAt,
      source: source,
      activeStreamKind: playbackController.state.streamKind,
      activeStationName: activeStation?.displayName
    )
  }

  private func persist() {
    stateStore.save(
      PersistedAppState(
        preferences: preferences,
        history: history,
        cachedStations: stations,
        cachedNowPlaying: metadataByStationID,
        lastRefreshAt: lastRefreshAt,
        source: source,
        songHistoryByStationID: songHistoryByStationID
      )
    )
  }

  private func syncVolumePreferencesFromPlaybackController() {
    preferences.volume = playbackController.volume
    preferences.muted = playbackController.isMuted
  }

  private func syncSystemNowPlaying() {
    playbackController.updateNowPlaying(station: activeStation, metadata: activeMetadata)
  }

  private func invalidateStatsSnapshot() {
    statsProvider.invalidate()
    statsSnapshotRevision &+= 1
  }

  private func applyRecentSongs(_ tracks: [NowPlaying], for stationID: String, metadataSignature: String) {
    liveRecentSongsByStationID[stationID] = tracks
    liveRecentFetchedAtByStationID[stationID] = .now
    liveRecentMetadataSignatureByStationID[stationID] = metadataSignature
  }

  private func normalizedRecentSongs(_ tracks: [NowPlaying], stationID: String) -> [NowPlaying] {
    let currentSignature = trackSignature(for: metadataByStationID[stationID])
    var seen: Set<String> = []

    return tracks
      .filter { !$0.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .filter { track in
        let signature = trackSignature(for: track)
        guard !signature.isEmpty else { return false }
        guard signature != currentSignature else { return false }
        return seen.insert(signature).inserted
      }
      .prefix(historyLength)
      .map { $0 }
  }

  private func trackSignature(for nowPlaying: NowPlaying?) -> String {
    guard let nowPlaying else { return "" }
    return [nowPlaying.artist, nowPlaying.title]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .joined(separator: "|")
  }
}

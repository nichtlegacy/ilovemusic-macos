import Foundation
import Testing
@testable import ILoveMusic

@Suite("AppStateStore persistence contract")
struct AppStateStoreTests {

  // MARK: - Helpers

  private func makeTempSupportDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func makeStateStore(supportDirectoryURL: URL) -> AppStateStore {
    AppStateStore(
      supportDirectoryURL: supportDirectoryURL,
      writeMode: .immediate
    )
  }

  private func sampleStation(id: String = "test-1") -> Station {
    Station(
      id: id,
      remoteID: id,
      name: "I♥Test",
      slug: "test",
      category: .popHits,
      accentHex: "#FF0000",
      aacStreamURLString: nil,
      mp3StreamURLString: nil,
      m3uURLString: nil,
      websiteURLString: "https://example.invalid",
      iconURLString: nil,
      tagline: "",
      featured: false,
      listenerCount: 42
    )
  }

  // MARK: - Load/save contracts

  @Test
  func loadReturnsDefaultWhenFileMissing() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let loaded = store.load()

    #expect(loaded.preferences == UserPreferences.default)
    #expect(loaded.history.isEmpty)
    #expect(loaded.cachedStations.isEmpty)
    #expect(loaded.cachedNowPlaying.isEmpty)
    #expect(loaded.source == .bundled)
    #expect(loaded.lastRefreshAt == nil)
    #expect(store.lastLoadOutcome == .missingFile)
  }

  @Test
  func saveThenLoadRoundTripsAllFields() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    var prefs = UserPreferences.default
    prefs.favoriteIDs = ["a", "b"]
    prefs.lastStationID = "a"
    prefs.volume = 0.42
    prefs.appLanguage = .german

    let station = sampleStation(id: "a")
    let nowPlaying = NowPlaying(
      stationID: "a",
      artist: "Artist",
      title: "Title",
      artworkURLString: "https://example.invalid/art.png",
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let history = [PlaybackHistoryEntry(stationID: "a", playedAt: Date(timeIntervalSince1970: 1_700_000_100))]
    let songHistory = ["a": [nowPlaying]]
    let lastRefreshAt = Date(timeIntervalSince1970: 1_700_000_200)

    store.save(
      PersistedAppState(
        preferences: prefs,
        history: history,
        cachedStations: [station],
        cachedNowPlaying: ["a": nowPlaying],
        lastRefreshAt: lastRefreshAt,
        source: .live,
        songHistoryByStationID: songHistory
      )
    )

    let reloadedStore = makeStateStore(supportDirectoryURL: dir)
    let reloaded = reloadedStore.load()

    #expect(reloaded.preferences == prefs)
    #expect(reloaded.preferences.effectiveAppLanguage == .german)
    #expect(reloaded.history == history)
    #expect(reloaded.cachedStations.count == 1)
    #expect(reloaded.cachedStations.first?.id == "a")
    #expect(reloaded.cachedNowPlaying["a"]?.title == "Title")
    #expect(reloaded.lastRefreshAt == lastRefreshAt)
    #expect(reloaded.source == .live)
    #expect(reloaded.songHistoryByStationID?["a"]?.count == 1)
    #expect(reloadedStore.lastLoadOutcome == .loaded)
    #expect(store.lastSaveOutcome == .saved)
  }

  @Test
  func saveWritesStateFileOwnerReadableOnly() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    store.save(.default)
    store.flushPendingWrites()

    let fileURL = dir.appendingPathComponent("state.json")
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let permissions = attributes[.posixPermissions] as? NSNumber

    // state.json holds preferences and listening history metadata, so it gets
    // the same 0600 treatment as play_events.jsonl and control.json.
    #expect(permissions?.int16Value == 0o600)
  }

  @Test
  func repeatedSavesKeepOwnerOnlyPermissions() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    store.save(.default)
    store.flushPendingWrites()
    // An atomic write swaps in a fresh file, so the mode has to survive a
    // second save rather than being set once at creation.
    store.save(.default)
    store.flushPendingWrites()

    let fileURL = dir.appendingPathComponent("state.json")
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.int16Value == 0o600)
  }

  @Test
  func loadReturnsDefaultWhenFileIsCorrupted() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let fileURL = dir.appendingPathComponent("state.json")
    try Data("{ not valid json".utf8).write(to: fileURL)

    let store = makeStateStore(supportDirectoryURL: dir)
    let loaded = store.load()

    // Phase 2 contract: corrupted file still falls back to defaults, but
    // the failure is now visible via lastLoadOutcome AND the bad file is
    // moved aside so a developer can inspect it later.
    #expect(loaded.preferences == UserPreferences.default)
    #expect(loaded.cachedStations.isEmpty)
    if case let .decodeFailed(_, quarantinedURL) = store.lastLoadOutcome {
      #expect(quarantinedURL != nil)
      if let quarantinedURL {
        #expect(FileManager.default.fileExists(atPath: quarantinedURL.path))
        #expect(quarantinedURL.lastPathComponent.contains(".corrupted.json"))
      }
    } else {
      Issue.record("Expected decodeFailed outcome, got \(store.lastLoadOutcome)")
    }

    // The original state.json should be gone (moved into the quarantine slot).
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test
  func saveAfterCorruptedLoadProducesFreshStateFile() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let fileURL = dir.appendingPathComponent("state.json")
    try Data("garbage".utf8).write(to: fileURL)

    let store = makeStateStore(supportDirectoryURL: dir)
    _ = store.load() // triggers quarantine

    // A subsequent save should succeed and recreate state.json cleanly.
    store.save(.default)
    #expect(store.lastSaveOutcome == .saved)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))

    // The quarantined file should still be around for inspection.
    let dirContents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    #expect(dirContents.contains(where: { $0.contains(".corrupted.json") }))
  }

  @Test
  func saveFailureReportsWriteFailedOutcome() throws {
    // Point the store at a directory that does not exist so the atomic
    // write fails. This exercises the .writeFailed branch without needing
    // to fiddle with file permissions.
    let nonexistentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("does-not-exist-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("nested", isDirectory: true)
    // Intentionally do NOT create it.

    let store = AppStateStore(
      supportDirectoryURL: nonexistentDir,
      writeMode: .immediate
    )
    store.save(.default)

    if case .writeFailed = store.lastSaveOutcome {
      // expected
    } else {
      Issue.record("Expected writeFailed outcome, got \(store.lastSaveOutcome)")
    }
  }

  @Test
  func clearCatalogCachePreservesPreferencesAndHistory() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    var prefs = UserPreferences.default
    prefs.favoriteIDs = ["a"]
    prefs.lastStationID = "a"
    let history = [PlaybackHistoryEntry(stationID: "a", playedAt: Date(timeIntervalSince1970: 1_700_000_100))]
    let station = sampleStation(id: "a")
    let nowPlaying = NowPlaying(
      stationID: "a",
      artist: "Artist",
      title: "Title",
      artworkURLString: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    store.save(
      PersistedAppState(
        preferences: prefs,
        history: history,
        cachedStations: [station],
        cachedNowPlaying: ["a": nowPlaying],
        lastRefreshAt: Date(),
        source: .live,
        songHistoryByStationID: nil
      )
    )

    store.clearCatalogCache()

    let reloaded = store.load()
    #expect(reloaded.preferences == prefs)
    #expect(reloaded.history == history)
    #expect(reloaded.cachedStations.isEmpty)
    #expect(reloaded.cachedNowPlaying.isEmpty)
    #expect(reloaded.lastRefreshAt == nil)
  }
}

@Suite("CatalogRepository bootstrap source selection")
struct CatalogBootstrapTests {

  private func makeTempSupportDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func makeStateStore(supportDirectoryURL: URL) -> AppStateStore {
    AppStateStore(
      supportDirectoryURL: supportDirectoryURL,
      writeMode: .immediate
    )
  }

  private func cachedStation() -> Station {
    Station(
      id: "cached-1",
      remoteID: "cached-1",
      name: "I♥Cached",
      slug: "cached",
      category: .popHits,
      accentHex: "#000000",
      aacStreamURLString: nil,
      mp3StreamURLString: nil,
      m3uURLString: nil,
      websiteURLString: "https://example.invalid",
      iconURLString: nil,
      tagline: "",
      featured: false,
      listenerCount: nil
    )
  }

  @Test
  func bootstrapReturnsBundledSourceWhenNoCacheExists() async throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let repository = CatalogRepository(
      apiClient: ILoveMusicAPIClient(),
      seedRepository: SeedRepository(),
      stateStore: store
    )

    let snapshot = await repository.bootstrapCatalog()

    #expect(snapshot.source == .bundled)
    // Either the seed has entries or it does not, but the source contract must hold.
    #expect(snapshot.stations.count == snapshot.rawStationCount)
  }

  @Test
  func bootstrapReturnsCachedSourceWhenStateHasCachedStations() async throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let station = cachedStation()
    let lastRefresh = Date(timeIntervalSince1970: 1_700_000_000)
    store.save(
      PersistedAppState(
        preferences: .default,
        history: [],
        cachedStations: [station],
        cachedNowPlaying: [:],
        lastRefreshAt: lastRefresh,
        source: .live,
        songHistoryByStationID: nil
      )
    )

    let repository = CatalogRepository(
      apiClient: ILoveMusicAPIClient(),
      seedRepository: SeedRepository(),
      stateStore: store
    )

    let snapshot = await repository.bootstrapCatalog()
    #expect(snapshot.source == .cached)
    #expect(snapshot.stations.count == 1)
    #expect(snapshot.stations.first?.id == station.id)
    #expect(snapshot.updatedAt == lastRefresh)
  }

  @Test
  func bootstrapForceSeedOnlyIgnoresCachedStations() async throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    store.save(
      PersistedAppState(
        preferences: .default,
        history: [],
        cachedStations: [cachedStation()],
        cachedNowPlaying: [:],
        lastRefreshAt: Date(),
        source: .live,
        songHistoryByStationID: nil
      )
    )

    let repository = CatalogRepository(
      apiClient: ILoveMusicAPIClient(),
      seedRepository: SeedRepository(),
      stateStore: store
    )

    let snapshot = await repository.bootstrapCatalog(forceSeedOnly: true)
    #expect(snapshot.source == .bundled)
    // Cached station id must not appear when we forced seed-only.
    #expect(!snapshot.stations.contains(where: { $0.id == "cached-1" }))
  }
}

@Suite("ControlDiagnosticsStore trimming and lifecycle")
struct ControlDiagnosticsStoreTests {

  private func makeTempSupportDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test
  func appendUpdatesLastOutcomeWithCount() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10)
    store.append(area: "Test", severity: .info, message: "hello")
    store.flush()
    if case .saved(let count) = store.lastOutcome {
      #expect(count == 1)
    } else {
      Issue.record("Expected .saved outcome, got \(store.lastOutcome)")
    }

    // Reload from disk in a fresh store so we exercise the on-disk path.
    let reopened = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10)
    let loaded = reopened.load()
    #expect(loaded.count == 1)
    if case .loaded(let count) = reopened.lastOutcome {
      #expect(count == 1)
    } else {
      Issue.record("Expected .loaded outcome, got \(reopened.lastOutcome)")
    }
  }

  @Test
  func loadFromCorruptedFileReturnsEmptyAndReportsFailure() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let fileURL = dir.appendingPathComponent("control-log.json")
    try Data("not json".utf8).write(to: fileURL)

    let store = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10)
    let loaded = store.load()
    #expect(loaded.isEmpty)
    if case .loadFailed = store.lastOutcome {
      // expected
    } else {
      Issue.record("Expected .loadFailed outcome, got \(store.lastOutcome)")
    }
  }

  @Test
  func appendTrimsToMaxEntries() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 5)
    for i in 0..<8 {
      store.append(area: "Test", severity: .info, message: "msg-\(i)")
    }
    store.flush()

    // In-memory cache reflects trimming immediately.
    let entries = store.load()
    #expect(entries.count == 5)
    // After trimming we should have kept the latest five messages.
    #expect(entries.first?.message == "msg-3")
    #expect(entries.last?.message == "msg-7")

    // Disk state matches after flush.
    let reopened = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 5).load()
    #expect(reopened.count == 5)
    #expect(reopened.first?.message == "msg-3")
    #expect(reopened.last?.message == "msg-7")
  }

  @Test
  func clearEmptiesStore() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10)
    store.append(area: "Test", severity: .info, message: "hello")
    #expect(store.load().count == 1)
    store.clear()
    #expect(store.load().isEmpty)

    // Disk file is empty too, since clear() writes synchronously.
    let reopened = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10).load()
    #expect(reopened.isEmpty)
  }

  @Test
  func loadReturnsEmptyWhenFileMissing() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = ControlDiagnosticsStore(supportDirectoryURL: dir, maxEntries: 10)
    #expect(store.load().isEmpty)
  }
}

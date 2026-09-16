import Foundation

struct CatalogRepository {
  private let apiClient: ILoveMusicAPIClient
  private let seedRepository: SeedRepository
  private let stateStore: AppStateStore
  private let normalizer = CatalogNormalizer()

  init(apiClient: ILoveMusicAPIClient, seedRepository: SeedRepository, stateStore: AppStateStore) {
    self.apiClient = apiClient
    self.seedRepository = seedRepository
    self.stateStore = stateStore
  }

  func bootstrapCatalog(forceSeedOnly: Bool = false) async -> CatalogSnapshot {
    let persisted = stateStore.load()
    if !forceSeedOnly, !persisted.cachedStations.isEmpty {
      return CatalogSnapshot(
        stations: persisted.cachedStations,
        playlistEntries: persisted.cachedNowPlaying,
        source: .cached,
        updatedAt: persisted.lastRefreshAt ?? .now,
        rawStationCount: persisted.cachedStations.count,
        filteredOutCount: 0
      )
    }

    let seedStations = seedRepository.loadStations()
    return CatalogSnapshot(
      stations: seedStations,
      playlistEntries: [:],
      source: .bundled,
      updatedAt: .now,
      rawStationCount: seedStations.count,
      filteredOutCount: 0
    )
  }

  func refreshCatalog() async -> CatalogSnapshot {
    let seedStations = seedRepository.loadStations()
    let policy = seedRepository.loadVisibilityPolicy()

    do {
      async let channels = apiClient.fetchChannels()
      async let playlist = apiClient.fetchPlaylist()
      async let listeners = apiClient.fetchListenerCounts()

      let normalized = normalizer.normalize(
        liveChannels: try await channels,
        playlist: try await playlist,
        listeners: (try? await listeners.channels) ?? [:],
        seedStations: seedStations,
        visibilityPolicy: policy
      )

      return CatalogSnapshot(
        stations: normalized.stations,
        playlistEntries: normalized.metadataByStationID,
        source: .live,
        updatedAt: .now,
        rawStationCount: normalized.rawStationCount,
        filteredOutCount: normalized.filteredOutCount
      )
    } catch {
      let persisted = stateStore.load()
      if !persisted.cachedStations.isEmpty {
        return CatalogSnapshot(
          stations: persisted.cachedStations,
          playlistEntries: persisted.cachedNowPlaying,
          source: .degraded,
          updatedAt: persisted.lastRefreshAt ?? .now,
          rawStationCount: persisted.cachedStations.count,
          filteredOutCount: 0
        )
      }

      return CatalogSnapshot(
        stations: seedStations,
        playlistEntries: [:],
        source: .degraded,
        updatedAt: .now,
        rawStationCount: seedStations.count,
        filteredOutCount: 0
      )
    }
  }

  func refreshListeners(currentStations: [Station]) async -> [Station] {
    do {
      let listeners = try await apiClient.fetchListenerCounts()
      return normalizer.applyListenerCounts(listeners.channels ?? [:], to: currentStations)
    } catch {
      return currentStations
    }
  }

  func refreshMetadata(currentStations: [Station]) async -> [String: NowPlaying] {
    do {
      let playlist = try await apiClient.fetchPlaylist()
      return normalizer.mapMetadataSnapshot(playlist: playlist, currentStations: currentStations)
    } catch {
      return [:]
    }
  }

  func fetchM3U(url: URL) async throws -> String {
    try await apiClient.fetchM3U(url: url)
  }

  func fetchRecentTracks(for station: Station, referenceDate: Date = .now) async -> [NowPlaying] {
    do {
      let todayTracks = try await apiClient.fetchRecentTracks(channelID: station.remoteID, date: referenceDate)
      if !todayTracks.isEmpty {
        return mapRecentTracks(todayTracks, stationID: station.id, referenceDate: referenceDate)
      }

      let yesterday = referenceDate.addingTimeInterval(-86_400)
      let fallbackTracks = try await apiClient.fetchRecentTracks(channelID: station.remoteID, date: yesterday)
      return mapRecentTracks(fallbackTracks, stationID: station.id, referenceDate: yesterday)
    } catch {
      return []
    }
  }

  private func mapRecentTracks(
    _ tracks: [LiveRecentTrackDTO],
    stationID: String,
    referenceDate: Date
  ) -> [NowPlaying] {
    tracks.map { track in
      NowPlaying(
        stationID: stationID,
        artist: track.artist.trimmingCharacters(in: .whitespacesAndNewlines),
        title: track.title.trimmingCharacters(in: .whitespacesAndNewlines),
        artworkURLString: normalizedAbsoluteURL(track.cover),
        updatedAt: parsedRecentTrackDate(track.timeLabel, referenceDate: referenceDate) ?? referenceDate
      )
    }
  }

  private func normalizedAbsoluteURL(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    if value.hasPrefix("http://") || value.hasPrefix("https://") {
      return value.replacingOccurrences(of: "http://", with: "https://")
    }
    return URL(string: value, relativeTo: URL(string: "https://ilovemusic.de"))?.absoluteURL.absoluteString
  }

  private func parsedRecentTrackDate(_ value: String?, referenceDate: Date) -> Date? {
    guard let value else { return nil }

    let normalized = value
      .replacingOccurrences(of: "Uhr", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let parts = normalized.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
      return nil
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    let day = calendar.startOfDay(for: referenceDate)
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
  }
}

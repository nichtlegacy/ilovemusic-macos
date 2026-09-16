import Foundation

extension AppModel: ControlServer.Delegate {
  func controlServerSnapshot() async -> ControlSnapshot {
    let phase = phaseString(playbackPhase: activePlaybackPhase)
    let station = activeStation.map {
      ControlStation(id: $0.id, name: $0.displayName, iconURL: bestIconURL(for: $0))
    }
    let favorite = activeStation.map { preferences.favoriteIDs.contains($0.id) } ?? false
    let np = activeMetadata.map { meta in
      ControlNowPlaying(
        artist: meta.artist.isEmpty ? nil : meta.artist,
        title: meta.title.isEmpty ? nil : meta.title,
        artworkURL: meta.artworkURLString
      )
    }
    return ControlSnapshot(
      phase: phase,
      station: station,
      nowPlaying: np,
      favorite: favorite,
      volume: activeVolumePercent,
      muted: isVolumeMuted
    )
  }

  func controlServerStations() async -> [ControlStation] {
    visibleStations.map {
      ControlStation(id: $0.id, name: $0.displayName, iconURL: bestIconURL(for: $0))
    }
  }

  func controlServerVolume() async -> ControlVolume {
    ControlVolume(volume: activeVolumePercent, muted: isVolumeMuted)
  }

  /// Prefer the current song artwork (more visually interesting and unique per station)
  /// and fall back to the station's own logo, which the live API often omits.
  private func bestIconURL(for station: Station) -> String? {
    metadataByStationID[station.id]?.artworkURLString ?? station.iconURLString
  }

  func controlServerToggle() async {
    await togglePlayback()
  }

  func controlServerToggleFavorite() async {
    guard let activeStationID else { return }
    toggleFavorite(activeStationID)
  }

  func controlServerPlay() async {
    switch activePlaybackPhase {
    case .playing, .buffering, .reconnecting:
      return
    case .paused, .idle, .failed:
      if let station = activeStation {
        await play(station)
      }
    }
  }

  func controlServerPause() async {
    switch activePlaybackPhase {
    case .playing, .buffering, .reconnecting:
      await togglePlayback()
    case .paused, .idle, .failed:
      return
    }
  }

  func controlServerNext() async {
    await playNextStation()
  }

  func controlServerRandom(favoritesOnly: Bool) async -> Bool {
    await playRandomStation(favoritesOnly: favoritesOnly)
  }

  func controlServerSelect(stationID: String) async {
    guard let station = stations.first(where: { $0.id == stationID }) else { return }
    await play(station)
  }

  func controlServerSetVolume(_ value: Int) async {
    updateVolumePercent(value)
  }

  func controlServerStepVolume(_ delta: Int) async {
    stepVolume(delta)
  }

  func controlServerSetMuted(_ muted: Bool?) async {
    if let muted {
      setMuted(muted)
    } else {
      toggleMute()
    }
  }

  private func phaseString(playbackPhase phase: PlaybackPhase) -> String {
    switch phase {
    case .idle: return "idle"
    case .buffering: return "buffering"
    case .playing: return "playing"
    case .paused: return "paused"
    case .reconnecting: return "reconnecting"
    case .failed: return "failed"
    }
  }
}

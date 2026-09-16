@preconcurrency import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class PlaybackController {
  private(set) var state: PlaybackState = .idle
  private(set) var volume: Double = UserPreferences.default.volume
  private(set) var isMuted: Bool = UserPreferences.default.muted ?? false

  @ObservationIgnored let player = AVPlayer()
  @ObservationIgnored private let apiClient = ILoveMusicAPIClient()
  @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
  @ObservationIgnored private var timeControlObservation: NSKeyValueObservation?
  @ObservationIgnored private var stallObserver: NSObjectProtocol?
  @ObservationIgnored private var currentStation: Station?
  @ObservationIgnored private var currentNowPlaying: NowPlaying?
  @ObservationIgnored private var reconnectAttempts = 0
  @ObservationIgnored private let maxReconnectAttempts = 5

  /// Monotonic token for playback load attempts. Resolving a stream is async, so
  /// a request started before the user switched station, paused, or stopped can
  /// still return afterwards. Anything that outlives its generation is dropped
  /// instead of starting a stream nobody asked for or overwriting newer state.
  @ObservationIgnored private var loadGeneration: UInt64 = 0
  @ObservationIgnored private var reconnectTask: Task<Void, Never>?

  /// Output gain ceiling applied on top of the perceptual curve. Capped below
  /// full power by default so the slider's usable range spreads out for
  /// low-level listening; `setMaxVolumeUnlocked(true)` restores full output.
  @ObservationIgnored private static let cappedMaxGain: Double = 0.7
  @ObservationIgnored private var maxVolumeUnlocked = false
  @ObservationIgnored var onPlaybackStateChanged: ((PlaybackState) -> Void)?
  @ObservationIgnored var onPlayRequested: (@MainActor () async -> Void)?
  @ObservationIgnored var onNextRequested: (@MainActor () async -> Void)?

  init() {
    player.automaticallyWaitsToMinimizeStalling = true
    player.allowsExternalPlayback = true
    applyEffectiveVolume()

    timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
      let status = player.timeControlStatus
      Task { @MainActor in
        self?.handleTimeControlStatus(status)
      }
    }

    configureRemoteCommands()
  }

  var volumePercent: Int {
    Int((volume * 100).rounded())
  }

  func restoreVolume(volume: Double, muted: Bool) {
    self.volume = Self.clampNormalized(volume)
    self.isMuted = muted
    applyEffectiveVolume()
  }

  func setVolume(_ value: Double) {
    volume = Self.clampNormalized(value)
    if volume > 0 { isMuted = false }
    applyEffectiveVolume()
  }

  func setVolumePercent(_ value: Int) {
    let clamped = Self.clampPercent(value)
    volume = Double(clamped) / 100
    if clamped > 0 { isMuted = false }
    applyEffectiveVolume()
  }

  func stepVolume(by delta: Int) {
    let next = Self.clampPercent(volumePercent + delta)
    volume = Double(next) / 100
    if delta > 0 && isMuted {
      isMuted = false
    }
    applyEffectiveVolume()
  }

  func setMuted(_ muted: Bool) {
    isMuted = muted
    applyEffectiveVolume()
  }

  func toggleMute() {
    isMuted.toggle()
    applyEffectiveVolume()
  }

  func setMaxVolumeUnlocked(_ unlocked: Bool) {
    maxVolumeUnlocked = unlocked
    applyEffectiveVolume()
  }

  private func applyEffectiveVolume() {
    let cap = maxVolumeUnlocked ? 1.0 : Self.cappedMaxGain
    let curved = pow(volume, 2.0) * cap
    player.volume = Float(isMuted ? 0 : curved)
  }

  func play(station: Station) async {
    let generation = invalidatePendingLoads()
    currentStation = station
    reconnectAttempts = 0
    state = PlaybackState(
      stationID: station.id,
      phase: .buffering,
      resolvedStreamURLString: nil,
      errorMessage: nil,
      streamKind: nil
    )
    emitState()

    await loadAndPlay(station: station, generation: generation)
  }

  /// Bumps the load generation and drops any scheduled reconnect, so work that
  /// is already in flight becomes a no-op. Returns the new current generation.
  @discardableResult
  private func invalidatePendingLoads() -> UInt64 {
    loadGeneration &+= 1
    reconnectTask?.cancel()
    reconnectTask = nil
    return loadGeneration
  }

  /// Resolves the stream and starts a fresh `AVPlayerItem`. Shared by the
  /// initial `play(station:)` and stall recovery — a live stream can't resume
  /// from a stale buffer, so reconnecting must rebuild the item, not just
  /// call `player.play()` on the dead one.
  private func loadAndPlay(station: Station, generation: UInt64) async {
    do {
      let resolution = try await resolveStream(for: station)
      guard generation == loadGeneration else { return }
      let item = AVPlayerItem(url: resolution.url)
      observe(item: item)
      player.replaceCurrentItem(with: item)
      player.play()
      state.resolvedStreamURLString = resolution.url.absoluteString
      state.streamKind = resolution.kind
      state.phase = .buffering
      state.errorMessage = nil
      emitState()
    } catch {
      guard generation == loadGeneration else { return }
      state.phase = .failed
      state.errorMessage = error.localizedDescription
      emitState()
    }
  }

  func updateNowPlaying(station: Station?, metadata: NowPlaying?) {
    currentStation = station
    currentNowPlaying = metadata
    refreshNowPlayingInfo()
  }

  func pause() {
    invalidatePendingLoads()
    player.pause()
    state.phase = .paused
    emitState()
  }

  func resume() {
    guard player.currentItem != nil else { return }
    player.play()
    state.phase = .playing
    emitState()
  }

  func stop() {
    invalidatePendingLoads()
    player.pause()
    player.replaceCurrentItem(with: nil)
    itemStatusObservation?.invalidate()
    itemStatusObservation = nil
    if let stallObserver {
      NotificationCenter.default.removeObserver(stallObserver)
      self.stallObserver = nil
    }
    currentStation = nil
    currentNowPlaying = nil
    state = .idle
    emitState()
  }

  private func resolveStream(for station: Station) async throws -> (url: URL, kind: String) {
    let candidates: [(String, String?)] = [
      ("AAC", station.aacStreamURLString),
      ("MP3", station.mp3StreamURLString)
    ]

    for (kind, value) in candidates {
      if let value, let url = URL(string: value), !value.isEmpty {
        return (url, kind)
      }
    }

    if let m3uURLString = station.m3uURLString, let m3uURL = URL(string: m3uURLString) {
      // Goes through the API client so a 404/500 error page is rejected instead
      // of being scanned for a stream URL and reported as a successful resolve.
      let text = try await apiClient.fetchM3U(url: m3uURL)
      for line in text.split(whereSeparator: \.isNewline) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"), let url = URL(string: trimmed) {
          return (url, "M3U")
        }
      }
    }

    throw URLError(.badURL)
  }

  private func observe(item: AVPlayerItem) {
    let generation = loadGeneration

    itemStatusObservation?.invalidate()
    itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      let status = item.status
      let error = item.error
      Task { @MainActor in
        guard status == .failed else { return }
        guard let self, generation == self.loadGeneration else { return }
        self.state.phase = .failed
        self.state.errorMessage = error?.localizedDescription ?? "Stream failed to start."
        self.emitState()
      }
    }

    if let stallObserver {
      NotificationCenter.default.removeObserver(stallObserver)
    }
    stallObserver = NotificationCenter.default.addObserver(
      forName: AVPlayerItem.playbackStalledNotification,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, generation == self.loadGeneration else { return }
        self.handlePlaybackStall()
      }
    }
  }

  private func handlePlaybackStall() {
    guard reconnectAttempts < maxReconnectAttempts else {
      state.phase = .failed
      state.errorMessage = "Stream stalled too often."
      emitState()
      return
    }

    reconnectAttempts += 1
    state.phase = .reconnecting
    emitState()

    let delay = UInt64(pow(2.0, Double(reconnectAttempts))) * 500_000_000
    let generation = loadGeneration
    reconnectTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: delay)
      guard !Task.isCancelled else { return }
      guard let self, generation == self.loadGeneration, let station = self.currentStation else { return }
      // Rebuild the item rather than resuming the stalled one.
      await self.loadAndPlay(station: station, generation: generation)
    }
  }

  private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
    switch status {
    case .playing:
      reconnectAttempts = 0
      state.phase = .playing
    case .waitingToPlayAtSpecifiedRate:
      if state.phase != .failed {
        state.phase = .buffering
      }
    case .paused:
      if state.phase == .playing {
        state.phase = .paused
      }
    @unknown default:
      break
    }

    emitState()
  }

  private func emitState() {
    refreshNowPlayingInfo()
    onPlaybackStateChanged?(state)
  }

  private func refreshNowPlayingInfo() {
    guard let station = currentStation else {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      return
    }

    let info: [String: Any] = [
      MPMediaItemPropertyTitle: currentNowPlaying?.title ?? station.displayName,
      MPMediaItemPropertyArtist: currentNowPlaying?.artist ?? station.category.title,
      MPMediaItemPropertyAlbumTitle: station.displayName,
      MPNowPlayingInfoPropertyPlaybackRate: state.phase == .playing ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyIsLiveStream: true
    ]

    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func configureRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.isEnabled = false

    commandCenter.playCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        switch self.state.phase {
        case .paused:
          self.resume()
        case .idle, .failed:
          await self.onPlayRequested?()
        case .playing, .buffering, .reconnecting:
          break
        }
      }
      return .success
    }

    commandCenter.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.pause()
      }
      return .success
    }

    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        switch self.state.phase {
        case .playing, .buffering, .reconnecting:
          self.pause()
        case .paused:
          self.resume()
        case .idle, .failed:
          await self.onPlayRequested?()
        }
      }
      return .success
    }

    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      guard let self, let onNextRequested else { return .commandFailed }
      Task { await onNextRequested() }
      return .success
    }
  }

  private static func clampNormalized(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }

  private static func clampPercent(_ value: Int) -> Int {
    min(max(value, 0), 100)
  }
}

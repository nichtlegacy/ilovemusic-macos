import Foundation
import Observation
import os

@MainActor
@Observable
final class PlayHistoryRecorder {
  nonisolated static let minimumListenSeconds = 10.0
  nonisolated static let maxRecoveryDuration: TimeInterval = 8 * 60 * 60

  private(set) var events: [PlayEvent] = []
  var onEventsChanged: (() -> Void)?

  @ObservationIgnored private let store: PlayHistoryStore
  @ObservationIgnored private let logger = Logger(subsystem: "com.nichtlegacy.ILoveMusic", category: "PlayHistoryRecorder")
  @ObservationIgnored private let nowProvider: () -> Date

  @ObservationIgnored private weak var appModel: AppModel?
  @ObservationIgnored private weak var playbackController: PlaybackController?
  @ObservationIgnored private var isEnabled = true
  @ObservationIgnored private var openEvent: PlayEvent?
  @ObservationIgnored private var openEventStartedPlayingAt: Date?
  @ObservationIgnored private var accumulatedListenedSeconds = 0.0

  init(store: PlayHistoryStore, nowProvider: @escaping () -> Date = { .now }) {
    self.store = store
    self.nowProvider = nowProvider
  }

  func bootstrap() {
    recoverOpenEvents(now: nowProvider())
    events = store.loadAll()
    syncOpenStateFromEvents()
    onEventsChanged?()
  }

  func attach(appModel: AppModel, playbackController: PlaybackController) {
    self.appModel = appModel
    self.playbackController = playbackController
    self.isEnabled = appModel.preferences.recordHistoryEnabled ?? true
    refreshFromAttachedState()
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    if !enabled {
      closeOpenEvent(reason: .paused)
      return
    }
    refreshFromAttachedState()
  }

  func closeOpenEvent(reason: PlayEventEndReason) {
    closeOpenEvent(reason: reason, now: nowProvider())
  }

  func refresh(station: Station?, metadata: NowPlaying?, state: PlaybackState) {
    sync(station: station, metadata: metadata, state: state, now: nowProvider())
  }

  func refreshFromAttachedState() {
    guard let appModel, let playbackController else { return }
    sync(
      station: appModel.activeStation,
      metadata: appModel.activeMetadata,
      state: playbackController.state,
      now: nowProvider()
    )
  }

  func reset() {
    closeOpenEvent(reason: .stopped)
    store.deleteAll()
    events = []
    openEvent = nil
    openEventStartedPlayingAt = nil
    accumulatedListenedSeconds = 0
    onEventsChanged?()
  }

  private func recoverOpenEvents(now: Date) {
    for event in store.loadOpenEvents() {
      var recovered = event
      let endedAt = min(now, event.startedAt.addingTimeInterval(Self.maxRecoveryDuration))
      recovered.endedAt = max(endedAt, event.startedAt)
      recovered.listenedSeconds = max(0, recovered.endedAt?.timeIntervalSince(event.startedAt) ?? 0)
      recovered.endReason = .crashRecovery
      store.append(recovered, flushToDisk: true)
    }
  }

  private func sync(station: Station?, metadata: NowPlaying?, state: PlaybackState, now: Date) {
    if let openEvent, let station, openEvent.stationID != station.id {
      closeOpenEvent(reason: .stationChanged, now: now)
    }

    if let openEvent, let station, state.stationID == station.id, let metadata, shouldSplitTrack(openEvent: openEvent, station: station, metadata: metadata) {
      closeOpenEvent(reason: .trackChanged, now: now)
    }

    guard isEnabled else { return }

    switch state.phase {
    case .playing:
      if openEvent == nil {
        guard let station, state.stationID == station.id, let metadata, shouldRecord(station: station, metadata: metadata) else { return }
        openNewEvent(station: station, metadata: metadata, now: now)
      } else if openEventStartedPlayingAt == nil {
        openEventStartedPlayingAt = now
      }

    case .buffering, .reconnecting:
      stopAccumulating(now: now)

    case .paused:
      stopAccumulating(now: now)
      closeOpenEvent(reason: .paused, now: now)

    case .idle, .failed:
      stopAccumulating(now: now)
      closeOpenEvent(reason: .stopped, now: now)
    }
  }

  private func openNewEvent(station: Station, metadata: NowPlaying, now: Date) {
    let event = PlayEvent(
      id: UUID(),
      stationID: station.id,
      stationName: station.displayName,
      stationCategory: station.category,
      stationAccentHex: station.accentHex,
      artist: metadata.artist.trimmingCharacters(in: .whitespacesAndNewlines),
      title: metadata.title.trimmingCharacters(in: .whitespacesAndNewlines),
      artworkURLString: metadata.artworkURLString,
      startedAt: now,
      endedAt: nil,
      listenedSeconds: nil,
      endReason: nil
    )
    openEvent = event
    openEventStartedPlayingAt = now
    accumulatedListenedSeconds = 0
    events.append(event)
    events.sort(by: sortEvents)
    store.append(event)
  }

  private func closeOpenEvent(reason: PlayEventEndReason, now: Date) {
    guard var event = openEvent else { return }

    stopAccumulating(now: now)

    let endedAt = max(now, event.startedAt)
    event.endedAt = endedAt
    event.listenedSeconds = accumulatedListenedSeconds
    event.endReason = reason

    openEvent = nil
    openEventStartedPlayingAt = nil
    accumulatedListenedSeconds = 0

    if shouldDiscard(event: event) {
      events.removeAll { $0.id == event.id }
      store.remove(eventID: event.id)
      onEventsChanged?()
      return
    }

    updateStoredEvent(event)
    store.append(event, flushToDisk: true)
    onEventsChanged?()
  }

  private func updateStoredEvent(_ event: PlayEvent) {
    guard let index = events.firstIndex(where: { $0.id == event.id }) else {
      events.append(event)
      events.sort(by: sortEvents)
      return
    }
    events[index] = event
  }

  private func syncOpenStateFromEvents() {
    openEvent = events.last(where: { $0.endedAt == nil })
    openEventStartedPlayingAt = nil
    accumulatedListenedSeconds = 0
  }

  private func stopAccumulating(now: Date) {
    guard let openEventStartedPlayingAt else { return }
    accumulatedListenedSeconds += max(0, now.timeIntervalSince(openEventStartedPlayingAt))
    self.openEventStartedPlayingAt = nil
  }

  private func shouldRecord(station: Station, metadata: NowPlaying) -> Bool {
    let artist = metadata.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let title = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !artist.isEmpty || !title.isEmpty else { return false }
    return !looksLikeJingle(artist: artist, title: title, stationName: station.displayName)
  }

  private func shouldDiscard(event: PlayEvent) -> Bool {
    let seconds = event.listenedSeconds ?? 0
    if seconds < Self.minimumListenSeconds {
      return true
    }

    return looksLikeJingle(
      artist: event.artist.trimmingCharacters(in: .whitespacesAndNewlines),
      title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
      stationName: event.stationName
    )
  }

  private func shouldSplitTrack(openEvent: PlayEvent, station: Station, metadata: NowPlaying) -> Bool {
    guard shouldRecord(station: station, metadata: metadata) else { return false }
    let nextArtist = metadata.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let nextTitle = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return openEvent.stationID != station.id
      || openEvent.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != nextArtist
      || openEvent.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != nextTitle
  }

  private func looksLikeJingle(artist: String, title: String, stationName: String) -> Bool {
    let combined = [artist, title]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .normalizedStationKey
    guard !combined.isEmpty else { return false }

    let stationKey = stationName.normalizedStationKey
    if !stationKey.isEmpty && combined == stationKey {
      return true
    }

    let noiseTokens = [
      "ilovemusic",
      "iloveradio",
      "stationid",
      "stationsound",
      "jingle"
    ]
    return noiseTokens.contains { combined.contains($0) }
  }

  private func sortEvents(_ lhs: PlayEvent, _ rhs: PlayEvent) -> Bool {
    if lhs.startedAt != rhs.startedAt {
      return lhs.startedAt < rhs.startedAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}

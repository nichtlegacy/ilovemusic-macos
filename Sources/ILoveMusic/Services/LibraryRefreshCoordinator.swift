import Foundation

/// Drives the three timer-based background refresh loops that keep the
/// library catalog, listener counts, and now-playing metadata fresh.
///
/// `AppModel` still owns the data and the three async entry points
/// (`refreshCatalog`, `refreshListeners`, `refreshMetadata`). This
/// coordinator owns the loop *lifecycle*: cancellation, restart, cadence.
///
/// The user-initiated path (`refreshAll()`) keeps using
/// `LibraryRefreshPipeline` directly for explicit catalog-first ordering.
@MainActor
final class LibraryRefreshCoordinator {
  /// Polling intervals for each refresh loop. The defaults match the
  /// long-standing production cadence; tests use shorter values to verify
  /// lifecycle without waiting minutes.
  struct Cadence: Sendable {
    let catalog: Duration
    let listeners: Duration
    let metadata: Duration

    static let production = Cadence(
      catalog: .seconds(900),
      listeners: .seconds(120),
      metadata: .seconds(30)
    )
  }

  private var catalogTask: Task<Void, Never>?
  private var listenersTask: Task<Void, Never>?
  private var metadataTask: Task<Void, Never>?

  private let cadence: Cadence

  init(cadence: Cadence = .production) {
    self.cadence = cadence
  }

  deinit {
    catalogTask?.cancel()
    listenersTask?.cancel()
    metadataTask?.cancel()
  }

  /// (Re)starts the three loops. If a previous run is in flight it is
  /// cancelled first so the coordinator never holds two copies of the
  /// same loop.
  func start(
    refreshCatalog: @escaping @MainActor @Sendable () async -> Void,
    refreshListeners: @escaping @MainActor @Sendable () async -> Void,
    refreshMetadata: @escaping @MainActor @Sendable () async -> Void
  ) {
    stop()

    let cadence = self.cadence
    catalogTask = Task { [refreshCatalog] in
      while !Task.isCancelled {
        try? await Task.sleep(for: cadence.catalog)
        if Task.isCancelled { return }
        await refreshCatalog()
      }
    }
    listenersTask = Task { [refreshListeners] in
      while !Task.isCancelled {
        try? await Task.sleep(for: cadence.listeners)
        if Task.isCancelled { return }
        await refreshListeners()
      }
    }
    metadataTask = Task { [refreshMetadata] in
      while !Task.isCancelled {
        try? await Task.sleep(for: cadence.metadata)
        if Task.isCancelled { return }
        await refreshMetadata()
      }
    }
  }

  /// Cancels and clears all running loops. Safe to call multiple times.
  func stop() {
    catalogTask?.cancel()
    listenersTask?.cancel()
    metadataTask?.cancel()
    catalogTask = nil
    listenersTask = nil
    metadataTask = nil
  }
}

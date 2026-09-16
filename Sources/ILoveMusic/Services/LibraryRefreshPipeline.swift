import Foundation

/// Sequencer for the multi-step library refresh.
///
/// The catalog must complete first because listener and metadata refreshes
/// depend on the current station set. Running them concurrently with the
/// catalog produces stale joins when stations are added/removed live.
///
/// Order:
///   1. `refreshCatalog` (await) — also reconciles the active station and
///      populates the initial metadata snapshot inside `AppModel`.
///   2. `refreshListeners` and `refreshMetadata` in parallel, against the
///      updated station set.
///   3. Return the catalog outcome to the caller for state reporting.
@MainActor
struct LibraryRefreshPipeline {
  /// Returns `true` when the catalog refresh produced a live snapshot.
  let refreshCatalog: @MainActor () async -> Bool
  let refreshListeners: @MainActor () async -> Void
  let refreshMetadata: @MainActor () async -> Void

  func run() async -> Bool {
    let catalogSuccess = await refreshCatalog()

    async let listeners: Void = refreshListeners()
    async let metadata: Void = refreshMetadata()
    _ = await listeners
    _ = await metadata

    return catalogSuccess
  }
}

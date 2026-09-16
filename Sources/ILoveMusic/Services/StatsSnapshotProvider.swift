import Foundation

/// Memoizes `PlayHistoryStats.snapshot(...)` results per `HistoryWindow`.
///
/// `AppModel` keeps the source-of-truth state (events, station lookup) and
/// delegates the cache-window match + recompute decision here. Invalidation
/// is explicit: whenever the inputs change, callers must call `invalidate()`.
///
/// Single-cache slot is intentional. The history/stats UI presents one
/// window at a time, so storing more than the most recent computation
/// would waste memory and complicate the invalidation contract.
@MainActor
final class StatsSnapshotProvider {
  private var cached: (window: HistoryWindow, snapshot: StatsSnapshot)?
  private(set) var computeCount: Int = 0

  /// Returns the cached snapshot when `window` matches the last call; otherwise
  /// recomputes via `compute()`, stores the result, and increments
  /// `computeCount` so tests can detect unwanted re-computation.
  func snapshot(
    for window: HistoryWindow,
    compute: () -> StatsSnapshot
  ) -> StatsSnapshot {
    if let cached, cached.window == window {
      return cached.snapshot
    }
    let snapshot = compute()
    computeCount += 1
    cached = (window, snapshot)
    return snapshot
  }

  /// Drops the cached entry so the next `snapshot(for:compute:)` call
  /// recomputes. Called whenever the inputs (history events or station set)
  /// change.
  func invalidate() {
    cached = nil
  }
}

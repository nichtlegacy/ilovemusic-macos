import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("StatsSnapshotProvider caching contract")
struct StatsSnapshotProviderTests {

  private func emptySnapshot(window: HistoryWindow = .lifetime) -> StatsSnapshot {
    PlayHistoryStats.snapshot(events: [], window: window, stationLookup: [:])
  }

  @Test
  func repeatedCallsForSameWindowReuseCachedResult() {
    let provider = StatsSnapshotProvider()
    var computed = 0

    let first = provider.snapshot(for: .lifetime) {
      computed += 1
      return self.emptySnapshot()
    }
    let second = provider.snapshot(for: .lifetime) {
      computed += 1
      return self.emptySnapshot()
    }

    #expect(computed == 1)
    #expect(provider.computeCount == 1)
    #expect(first == second)
  }

  @Test
  func differentWindowRecomputes() {
    let provider = StatsSnapshotProvider()
    var computed = 0

    _ = provider.snapshot(for: .lifetime) {
      computed += 1
      return self.emptySnapshot(window: .lifetime)
    }
    _ = provider.snapshot(for: .last7Days) {
      computed += 1
      return self.emptySnapshot(window: .last7Days)
    }

    #expect(computed == 2)
    #expect(provider.computeCount == 2)
  }

  @Test
  func invalidateForcesRecompute() {
    let provider = StatsSnapshotProvider()
    var computed = 0

    _ = provider.snapshot(for: .lifetime) {
      computed += 1
      return self.emptySnapshot()
    }
    provider.invalidate()
    _ = provider.snapshot(for: .lifetime) {
      computed += 1
      return self.emptySnapshot()
    }

    #expect(computed == 2)
    #expect(provider.computeCount == 2)
  }
}

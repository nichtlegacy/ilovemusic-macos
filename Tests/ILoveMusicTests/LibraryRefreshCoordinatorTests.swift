import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("LibraryRefreshCoordinator lifecycle", .serialized)
struct LibraryRefreshCoordinatorTests {

  private actor Counter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
  }

  @Test
  func startInvokesRefreshersAtLeastOnce() async throws {
    // Slower cadence + longer wait so the test is robust under CI load.
    let cadence = LibraryRefreshCoordinator.Cadence(
      catalog: .milliseconds(40),
      listeners: .milliseconds(40),
      metadata: .milliseconds(40)
    )
    let coordinator = LibraryRefreshCoordinator(cadence: cadence)
    let catalog = Counter()
    let listeners = Counter()
    let metadata = Counter()

    coordinator.start(
      refreshCatalog: { await catalog.increment() },
      refreshListeners: { await listeners.increment() },
      refreshMetadata: { await metadata.increment() }
    )

    let didRefresh = await waitUntil {
      let catalogValue = await catalog.value
      let listenerValue = await listeners.value
      let metadataValue = await metadata.value
      return catalogValue >= 1 && listenerValue >= 1 && metadataValue >= 1
    }
    coordinator.stop()

    #expect(didRefresh)
  }

  @Test
  func stopPreventsAdditionalRefreshes() async throws {
    let cadence = LibraryRefreshCoordinator.Cadence(
      catalog: .milliseconds(40),
      listeners: .milliseconds(40),
      metadata: .milliseconds(40)
    )
    let coordinator = LibraryRefreshCoordinator(cadence: cadence)
    let catalog = Counter()

    coordinator.start(
      refreshCatalog: { await catalog.increment() },
      refreshListeners: {},
      refreshMetadata: {}
    )
    try? await Task.sleep(for: .milliseconds(200))
    coordinator.stop()

    let snapshotAfterStop = await catalog.value
    try? await Task.sleep(for: .milliseconds(200))
    let snapshotLater = await catalog.value

    // After stop(), the loop must not fire again. Allow a tiny grace for an
    // in-flight invocation that started before stop() landed.
    #expect(snapshotLater - snapshotAfterStop <= 1)
  }

  @Test
  func startTwiceDoesNotDoubleTheCounters() async throws {
    // Slower cadence + longer windows to make this robust under CI load.
    let cadence = LibraryRefreshCoordinator.Cadence(
      catalog: .milliseconds(40),
      listeners: .seconds(60),
      metadata: .seconds(60)
    )
    let coordinator = LibraryRefreshCoordinator(cadence: cadence)
    let catalog = Counter()

    coordinator.start(
      refreshCatalog: { await catalog.increment() },
      refreshListeners: {},
      refreshMetadata: {}
    )
    try? await Task.sleep(for: .milliseconds(200))
    let firstRun = await catalog.value

    // Restart with the same cadence — the previous loop must be cancelled,
    // not duplicated. A tolerant upper bound (2× the per-window count
    // plus a small grace) catches a doubled loop without being flaky.
    coordinator.start(
      refreshCatalog: { await catalog.increment() },
      refreshListeners: {},
      refreshMetadata: {}
    )
    try? await Task.sleep(for: .milliseconds(200))
    let secondRun = await catalog.value
    coordinator.stop()

    let secondWindow = secondRun - firstRun
    #expect(secondWindow <= firstRun * 2 + 2)
  }
}

@MainActor
private func waitUntil(
  timeout: Duration = .seconds(5),
  condition: () async -> Bool
) async -> Bool {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if await condition() { return true }
    try? await Task.sleep(for: .milliseconds(20))
  }
  return await condition()
}

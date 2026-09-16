import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("LibraryRefreshPipeline ordering contract")
struct LibraryRefreshPipelineTests {

  private actor RefreshRecorder {
    enum Step: String, Sendable { case catalogStart, catalogEnd, listenersStart, listenersEnd, metadataStart, metadataEnd }
    private(set) var steps: [Step] = []
    func record(_ step: Step) { steps.append(step) }
    func snapshot() -> [Step] { steps }
  }

  @Test
  func catalogCompletesBeforeListenersOrMetadataBegin() async throws {
    let recorder = RefreshRecorder()

    let pipeline = LibraryRefreshPipeline(
      refreshCatalog: {
        await recorder.record(.catalogStart)
        // Yield a few times so listeners/metadata would have a chance to
        // start if they were not properly sequenced after the catalog.
        try? await Task.sleep(for: .milliseconds(20))
        await recorder.record(.catalogEnd)
        return true
      },
      refreshListeners: {
        await recorder.record(.listenersStart)
        await recorder.record(.listenersEnd)
      },
      refreshMetadata: {
        await recorder.record(.metadataStart)
        await recorder.record(.metadataEnd)
      }
    )

    let success = await pipeline.run()
    #expect(success)

    let steps = await recorder.snapshot()
    let catalogEndIndex = steps.firstIndex(of: .catalogEnd)
    let listenersStartIndex = steps.firstIndex(of: .listenersStart)
    let metadataStartIndex = steps.firstIndex(of: .metadataStart)

    #expect(catalogEndIndex != nil)
    #expect(listenersStartIndex != nil)
    #expect(metadataStartIndex != nil)
    #expect(catalogEndIndex! < listenersStartIndex!)
    #expect(catalogEndIndex! < metadataStartIndex!)
  }

  @Test
  func listenersAndMetadataRunConcurrentlyAfterCatalog() async throws {
    // Listener task holds briefly so metadata has time to start in parallel.
    // The recorded sequence should show metadataStart before listenersEnd.
    let recorder = RefreshRecorder()

    let pipeline = LibraryRefreshPipeline(
      refreshCatalog: { return true },
      refreshListeners: {
        await recorder.record(.listenersStart)
        try? await Task.sleep(for: .milliseconds(40))
        await recorder.record(.listenersEnd)
      },
      refreshMetadata: {
        await recorder.record(.metadataStart)
        await recorder.record(.metadataEnd)
      }
    )

    _ = await pipeline.run()
    let steps = await recorder.snapshot()

    let listenersStart = steps.firstIndex(of: .listenersStart)
    let metadataStart = steps.firstIndex(of: .metadataStart)
    let listenersEnd = steps.firstIndex(of: .listenersEnd)
    #expect(listenersStart != nil && metadataStart != nil && listenersEnd != nil)
    #expect(metadataStart! < listenersEnd!)
  }

  @Test
  func returnsFalseWhenCatalogReportsFailure() async {
    let pipeline = LibraryRefreshPipeline(
      refreshCatalog: { false },
      refreshListeners: {},
      refreshMetadata: {}
    )
    let success = await pipeline.run()
    #expect(success == false)
  }
}

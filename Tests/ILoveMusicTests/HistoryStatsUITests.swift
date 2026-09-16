import AppKit
import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("History and Stats UI")
struct HistoryStatsUITests {
  @Test
  func unknownPersistedDestinationFallsBackToHistory() throws {
    let name = "HistoryStatsUITests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }

    defaults.set("removed", forKey: HistoryStatsSelection.destinationKey)
    let selection = HistoryStatsSelection(defaults: defaults)

    #expect(selection.destination == .history)
    selection.destination = .stats
    #expect(defaults.string(forKey: HistoryStatsSelection.destinationKey) == "stats")
  }

  @Test
  func responsiveLayoutUsesStableBreakpoints() {
    #expect(StatsLayout.metricsColumns(for: 700) == 4)
    #expect(StatsLayout.metricsColumns(for: 560) == 2)
    #expect(StatsLayout.metricsColumns(for: 420) == 1)
    #expect(StatsLayout.supportingColumns(for: 900) == 2)
    #expect(StatsLayout.supportingColumns(for: 620) == 1)
    #expect(StatsLayout.rankingLimit(for: 900) == 8)
    #expect(StatsLayout.rankingLimit(for: 620) == 5)
  }

  @Test
  func emptyStateDependsOnTheSelectedWindow() {
    #expect(StatsLayout.showsPageEmptyState(eventCountInWindow: 0))
    #expect(!StatsLayout.showsPageEmptyState(eventCountInWindow: 1))
  }

  @Test
  func historyWindowUsesNativeResizableChrome() throws {
    let fixture = try makeModel()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let controller = HistoryStatsWindowController(appModel: fixture.model)
    let window = try #require(controller.window)

    #expect(HistoryStatsWindowController.defaultSize == NSSize(width: 1040, height: 760))
    #expect(window.contentMinSize == NSSize(width: 760, height: 560))
    #expect(window.styleMask.contains(.fullSizeContentView))
    #expect(window.styleMask.contains(.resizable))
    #expect(window.toolbarStyle == .unified)
    #expect(window.frameAutosaveName == "history-stats")
  }

  private func makeModel() throws -> (model: AppModel, directory: URL) {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = AppStateStore(supportDirectoryURL: directory, writeMode: .immediate)
    return (AppModel(playbackController: PlaybackController(), stateStoreOverride: store), directory)
  }
}

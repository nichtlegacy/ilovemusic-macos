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
  func chartSelectionClampsToVisibleSlots() {
    #expect(ChartSelection.index(at: -1, plotWidth: 240, count: 24) == nil)
    #expect(ChartSelection.index(at: 0, plotWidth: 240, count: 24) == 0)
    #expect(ChartSelection.index(at: 239, plotWidth: 240, count: 24) == 23)
    #expect(ChartSelection.index(at: 240, plotWidth: 240, count: 24) == nil)
    #expect(ChartSelection.index(at: 20, plotWidth: 0, count: 24) == nil)
  }

  @Test
  func chartEdgeLabelsUseReadableAlignment() {
    #expect(ChartSelection.edge(for: 0, count: 7) == .leading)
    #expect(ChartSelection.edge(for: 3, count: 7) == .center)
    #expect(ChartSelection.edge(for: 6, count: 7) == .trailing)
  }

  @Test
  func heatmapCoordinateNavigationStaysInBounds() {
    #expect(
      HeatmapSelection(row: 0, hour: 0).moving(rowDelta: -1, hourDelta: 0)
        == HeatmapSelection(row: 0, hour: 0)
    )
    #expect(
      HeatmapSelection(row: 6, hour: 23).moving(rowDelta: 1, hourDelta: 1)
        == HeatmapSelection(row: 6, hour: 23)
    )
    #expect(
      HeatmapSelection(row: 2, hour: 8).moving(rowDelta: 1, hourDelta: -1)
        == HeatmapSelection(row: 3, hour: 7)
    )
  }

  @Test
  func weekdaySymbolsFollowLocaleAndStayMondayFirst() {
    let english = localizedMondayFirstWeekdaySymbols(locale: Locale(identifier: "en_US"))
    let german = localizedMondayFirstWeekdaySymbols(locale: Locale(identifier: "de_DE"))

    #expect(english.first == "Mon")
    #expect(german.first == "Mo")
    #expect(english.last == "Sun")
    #expect(german.last == "So")
  }

  @Test
  func listeningDurationUsesTheRequestedLocale() {
    let english = formatShortListeningDuration(65, locale: Locale(identifier: "en_US"))
    let german = formatShortListeningDuration(65, locale: Locale(identifier: "de_DE"))

    #expect(!english.isEmpty)
    #expect(!german.isEmpty)
    #expect(formatShortListeningDuration(0, locale: Locale(identifier: "de_DE")) != "0 sec")
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

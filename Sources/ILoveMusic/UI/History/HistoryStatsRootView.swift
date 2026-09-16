import AppKit
import Observation
import SwiftUI

enum HistoryStatsTab: String, CaseIterable, Hashable, Identifiable {
  case history
  case stats

  var id: Self { self }
  var title: String { self == .history ? "History" : "Stats" }
  var symbol: String { self == .history ? "clock.arrow.circlepath" : "chart.bar.xaxis" }
}

@MainActor
@Observable
final class HistoryStatsSelection {
  static let destinationKey = "historyStats.selectedDestination"

  private let defaults: UserDefaults
  var destination: HistoryStatsTab {
    didSet { defaults.set(destination.rawValue, forKey: Self.destinationKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.destination = defaults.string(forKey: Self.destinationKey)
      .flatMap(HistoryStatsTab.init(rawValue:)) ?? .history
  }
}

struct HistoryStatsRootView: View {
  let appModel: AppModel
  let selection: HistoryStatsSelection

  @AppStorage("historyStatsWindow") private var historyStatsWindowRaw = HistoryWindow.last7Days.rawValue

  var body: some View {
    @Bindable var selection = selection

    content
      .toolbar {
        ToolbarItem(placement: .principal) {
          Picker("View", selection: $selection.destination) {
            ForEach(HistoryStatsTab.allCases) { tab in
              Label(tab.title, systemImage: tab.symbol).tag(tab)
            }
          }
          .pickerStyle(.segmented)
          .frame(width: 210)
        }

        if selection.destination == .stats {
          ToolbarItem(placement: .primaryAction) {
            Picker("Time Range", selection: $historyStatsWindowRaw) {
              Text("Today").tag(HistoryWindow.today.rawValue)
              Text("7 Days").tag(HistoryWindow.last7Days.rawValue)
              Text("30 Days").tag(HistoryWindow.last30Days.rawValue)
              Text("90 Days").tag(HistoryWindow.last90Days.rawValue)
              Text("All Time").tag(HistoryWindow.lifetime.rawValue)
            }
            .pickerStyle(.menu)
            .frame(width: 150)
          }
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    switch selection.destination {
    case .history:
      HistoryListView(appModel: appModel)
    case .stats:
      StatsView(
        appModel: appModel,
        window: HistoryWindow(rawValue: historyStatsWindowRaw) ?? .last7Days
      )
    }
  }

}

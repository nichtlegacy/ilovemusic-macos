import AppKit
import Observation
import SwiftUI

enum HistoryStatsTab: String, CaseIterable, Hashable, Identifiable {
  case history
  case stats

  var id: Self { self }
  var titleResource: LocalizedStringResource {
    switch self {
    case .history: LocalizedStringResource("History", bundle: #bundle)
    case .stats: LocalizedStringResource("Stats", bundle: #bundle)
    }
  }
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
  @Environment(\.locale) private var locale

  var body: some View {
    @Bindable var selection = selection

    content
      .toolbar {
        ToolbarItem(placement: .principal) {
          Picker(selection: $selection.destination) {
            ForEach(HistoryStatsTab.allCases) { tab in
              Label {
                Text(tab.titleResource.resolved(in: locale))
              } icon: {
                Image(systemName: tab.symbol)
              }
              .tag(tab)
            }
          } label: {
            Text("View", bundle: #bundle)
          }
          .pickerStyle(.segmented)
          .frame(width: 210)
        }

        if selection.destination == .stats {
          ToolbarItem(placement: .primaryAction) {
            Picker(selection: $historyStatsWindowRaw) {
              ForEach([HistoryWindow.today, .last7Days, .last30Days, .last90Days, .lifetime], id: \.self) { window in
                Text(window.titleResource.resolved(in: locale)).tag(window.rawValue)
              }
            } label: {
              Text("Time Range", bundle: #bundle)
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

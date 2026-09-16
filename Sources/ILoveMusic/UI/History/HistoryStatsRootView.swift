import AppKit
import SwiftUI

enum HistoryStatsTab: Hashable {
  case history
  case stats
}

struct HistoryStatsRootView: View {
  let appModel: AppModel

  @State private var selectedTab: HistoryStatsTab = .history
  @AppStorage("historyStatsWindow") private var historyStatsWindowRaw = HistoryWindow.last7Days.rawValue

  var body: some View {
    VStack(spacing: 0) {
      tabBar
      Divider()
      content
    }
    .frame(minWidth: 900, minHeight: 640)
    .background(.background)
  }

  private var tabBar: some View {
    HStack(spacing: 8) {
      tabButton(.history, label: "History", systemImage: "clock.arrow.circlepath")
      tabButton(.stats, label: "Stats", systemImage: "chart.bar.xaxis")
      Spacer()
      if selectedTab == .stats {
        Picker("Time range", selection: $historyStatsWindowRaw) {
          Text("Today").tag(HistoryWindow.today.rawValue)
          Text("Last 7 days").tag(HistoryWindow.last7Days.rawValue)
          Text("Last 30 days").tag(HistoryWindow.last30Days.rawValue)
          Text("Last 90 days").tag(HistoryWindow.last90Days.rawValue)
          Text("All time").tag(HistoryWindow.lifetime.rawValue)
        }
        .pickerStyle(.menu)
        .frame(width: 230)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var content: some View {
    switch selectedTab {
    case .history:
      HistoryListView(appModel: appModel)
    case .stats:
      StatsView(
        appModel: appModel,
        window: HistoryWindow(rawValue: historyStatsWindowRaw) ?? .last7Days
      )
    }
  }

  private func tabButton(_ tab: HistoryStatsTab, label: String, systemImage: String) -> some View {
    Button {
      selectedTab = tab
    } label: {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .semibold))
        Text(label)
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundStyle(selectedTab == tab ? .primary : .secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        Capsule(style: .continuous)
          .fill(selectedTab == tab ? Color.primary.opacity(0.10) : .clear)
      )
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
  }
}

import SwiftUI

struct StatsSummaryStrip: View {
  let snapshot: StatsSnapshot

  private var metrics: [(title: String, value: String, symbol: String, accent: Color)] {
    let hasEvents = snapshot.eventCountInWindow > 0
    return [
      (
        "Selected Period",
        hasEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsInWindow) : "—",
        "clock",
        .accentColor
      ),
      (
        "Today",
        hasEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsToday) : "—",
        "sun.max",
        .secondary
      ),
      (
        "Streak",
        hasEvents ? "\(snapshot.dailyStreak) days" : "—",
        "flame.fill",
        snapshot.dailyStreak >= 3 ? .orange : .secondary
      ),
      (
        "Average Session",
        hasEvents ? formatShortListeningDuration(snapshot.averageSessionSeconds) : "—",
        "timer",
        .secondary
      ),
    ]
  }

  var body: some View {
    StatsSection(title: "Overview") {
      ViewThatFits(in: .horizontal) {
        metricRow(metrics)
          .frame(minWidth: 680)
        VStack(spacing: 12) {
          metricRow(Array(metrics.prefix(2)))
          Divider()
          metricRow(Array(metrics.suffix(2)))
        }
        .frame(minWidth: 440)
        VStack(alignment: .leading, spacing: 12) {
          ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
            metricCell(metric)
            if index < metrics.count - 1 {
              Divider()
            }
          }
        }
      }
    }
  }

  private func metricRow(
    _ metrics: [(title: String, value: String, symbol: String, accent: Color)]
  ) -> some View {
    HStack(alignment: .top, spacing: 14) {
      ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
        metricCell(metric)
        if index < metrics.count - 1 {
          Divider()
        }
      }
    }
  }

  private func metricCell(
    _ metric: (title: String, value: String, symbol: String, accent: Color)
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: metric.symbol)
          .foregroundStyle(metric.accent)
        Text(metric.title)
          .foregroundStyle(.secondary)
      }
      .font(.system(size: 10, weight: .semibold))
      .textCase(.uppercase)

      Text(metric.value)
        .font(.system(size: 20, weight: .semibold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

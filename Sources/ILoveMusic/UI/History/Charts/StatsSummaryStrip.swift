import SwiftUI

struct StatsSummaryStrip: View {
  let snapshot: StatsSnapshot

  @Environment(\.locale) private var locale

  private var metrics: [(title: LocalizedStringResource, value: String, symbol: String, accent: Color)] {
    let hasEvents = snapshot.eventCountInWindow > 0
    return [
      (
        LocalizedStringResource("Selected Period", bundle: #bundle),
        hasEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsInWindow, locale: locale) : "—",
        "clock",
        .accentColor
      ),
      (
        LocalizedStringResource("Today", bundle: #bundle),
        hasEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsToday, locale: locale) : "—",
        "sun.max",
        .secondary
      ),
      (
        LocalizedStringResource("Streak", bundle: #bundle),
        hasEvents ? localizedDayCount(snapshot.dailyStreak, locale: locale) : "—",
        "flame.fill",
        snapshot.dailyStreak >= 3 ? .orange : .secondary
      ),
      (
        LocalizedStringResource("Average Session", bundle: #bundle),
        hasEvents ? formatShortListeningDuration(snapshot.averageSessionSeconds, locale: locale) : "—",
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
    _ metrics: [(title: LocalizedStringResource, value: String, symbol: String, accent: Color)]
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
    _ metric: (title: LocalizedStringResource, value: String, symbol: String, accent: Color)
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: metric.symbol)
          .foregroundStyle(metric.accent)
        Text(metric.title.resolved(in: locale))
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

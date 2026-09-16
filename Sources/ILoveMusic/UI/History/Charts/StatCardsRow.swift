import SwiftUI

struct StatCardsRow: View {
  let snapshot: StatsSnapshot

  var body: some View {
    HStack(spacing: 12) {
      StatCard(
        title: "Heute",
        value: snapshot.hasAnyEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsToday) : "—",
        systemImage: "clock"
      )
      StatCard(
        title: "Diese Woche",
        value: snapshot.hasAnyEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsThisWeek) : "—",
        systemImage: "calendar.day.timeline.left"
      )
      StatCard(
        title: "Dieser Monat",
        value: snapshot.hasAnyEvents ? formatShortListeningDuration(snapshot.totalListenedSecondsThisMonth) : "—",
        systemImage: "calendar"
      )
      StatCard(
        title: "Streak",
        value: snapshot.hasAnyEvents ? "\(snapshot.dailyStreak) Tage" : "—",
        systemImage: "flame.fill",
        accent: snapshot.dailyStreak >= 3 ? .orange : .secondary
      )
    }
  }
}

private struct StatCard: View {
  let title: String
  let value: String
  let systemImage: String
  var accent: Color = .secondary

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .textCase(.uppercase)
          .tracking(0.6)
          .foregroundStyle(.secondary)
        Spacer()
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accent)
      }

      Text(value)
        .font(.system(size: 22, weight: .bold).monospacedDigit())
        .foregroundStyle(.primary)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.regularMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
    )
  }
}

import Charts
import SwiftUI

struct GenreDonutChart: View {
  let shares: [GenreShare]

  var body: some View {
    if shares.isEmpty {
      StatsEmptyState(title: "No data", subtitle: "Genre distribution appears once there is some listening history.")
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) {
          donut(size: 132)
          legend
        }

        VStack(spacing: 14) {
          donut(size: 118)
          legend
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func donut(size: CGFloat) -> some View {
    ZStack {
      Chart(shares) { share in
        SectorMark(
          angle: .value("Time", share.listenedSeconds),
          innerRadius: .ratio(0.62),
          angularInset: 1
        )
        .foregroundStyle(share.category.chartColor)
        .accessibilityLabel(share.category.title)
        .accessibilityValue("\(percentString(share.share)), \(formatShortListeningDuration(share.listenedSeconds))")
      }

      VStack(spacing: 2) {
        Text(percentString(shares[0].share))
          .font(.title3.bold().monospacedDigit())
        Text(shares[0].category.title)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Genre distribution")
  }

  private var legend: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(shares) { share in
        HStack(spacing: 8) {
          Circle()
            .fill(share.category.chartColor)
            .frame(width: 8, height: 8)
          Text(share.category.title)
            .font(.caption)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text("\(percentString(share.share)) · \(formatShortListeningDuration(share.listenedSeconds))")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func percentString(_ value: Double) -> String {
    "\(Int((value * 100).rounded())) %"
  }
}

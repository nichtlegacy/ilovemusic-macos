import Charts
import SwiftUI

struct GenreDonutChart: View {
  let shares: [GenreShare]

  var body: some View {
    if shares.isEmpty {
      StatsEmptyState(title: "No data", subtitle: "Genre distribution appears once there is some listening history.")
    } else {
      HStack(spacing: 16) {
        ZStack {
          Chart(shares) { share in
            SectorMark(
              angle: .value("Time", share.listenedSeconds),
              innerRadius: .ratio(0.60)
            )
            .foregroundStyle(share.category.chartColor)
          }

          VStack(spacing: 4) {
            Text(percentString(shares[0].share))
              .font(.system(size: 20, weight: .bold).monospacedDigit())
            Text(shares[0].category.title)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        .frame(width: 150, height: 150)

        VStack(alignment: .leading, spacing: 10) {
          ForEach(shares) { share in
            HStack(spacing: 8) {
              Circle()
                .fill(share.category.chartColor)
                .frame(width: 8, height: 8)
              Text(share.category.title)
                .font(.system(size: 12, weight: .medium))
              Spacer()
              Text("\(percentString(share.share)) · \(formatShortListeningDuration(share.listenedSeconds))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func percentString(_ value: Double) -> String {
    "\(Int((value * 100).rounded())) %"
  }
}

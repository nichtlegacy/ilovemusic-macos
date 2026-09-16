import SwiftUI

struct WeekdayHourHeatmap: View {
  let matrix: [[Double]]

  private let weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
  private let hourMarkers = [0, 6, 12, 18, 23]
  private let rowLabelWidth: CGFloat = 24
  private let cellSpacing: CGFloat = 3
  private let maxCellSize: CGFloat = 14

  var body: some View {
    let maxValue = matrix.flatMap { $0 }.max() ?? 0

    GeometryReader { proxy in
      let usableWidth = max(0, proxy.size.width - rowLabelWidth - 8)
      let cellSize = min(
        maxCellSize,
        max(8, (usableWidth - (23 * cellSpacing)) / 24)
      )
      let gridWidth = (cellSize * 24) + (cellSpacing * 23)

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .bottom, spacing: 8) {
          Color.clear.frame(width: rowLabelWidth, height: 1)

          HStack(spacing: cellSpacing) {
            ForEach(0..<24, id: \.self) { hour in
              ZStack(alignment: .leading) {
                if hourMarkers.contains(hour) {
                  Text("\(hour)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: cellSize, alignment: hour == 23 ? .trailing : .leading)
                }
              }
              .frame(width: cellSize, height: 14, alignment: .leading)
            }
          }
          .frame(width: gridWidth, alignment: .leading)
        }

        VStack(alignment: .leading, spacing: cellSpacing) {
          ForEach(Array(matrix.enumerated()), id: \.offset) { rowIndex, row in
            HStack(spacing: 8) {
              Text(weekdayLabels[rowIndex])
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: rowLabelWidth, alignment: .leading)

              HStack(spacing: cellSpacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                  RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(opacity(for: value, maxValue: maxValue)))
                    .frame(width: cellSize, height: cellSize)
                }
              }
              .frame(width: gridWidth, alignment: .leading)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay {
      if maxValue == 0 {
        StatsEmptyState(title: "No data", subtitle: "The heatmap fills in as you listen more.")
      }
    }
  }

  private func opacity(for value: Double, maxValue: Double) -> Double {
    guard maxValue > 0 else { return 0.08 }
    return max(0.08, min(1, value / maxValue))
  }
}

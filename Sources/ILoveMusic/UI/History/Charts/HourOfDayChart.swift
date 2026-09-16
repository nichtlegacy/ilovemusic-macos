import Charts
import SwiftUI

struct HourOfDayChart: View {
  let secondsPerHour: [Double]

  var body: some View {
    Chart(Array(secondsPerHour.enumerated()), id: \.offset) { bucket in
      BarMark(
        x: .value("Stunde", bucket.offset),
        y: .value("Zeit", bucket.element)
      )
      .foregroundStyle(Color.accentColor.opacity(bucket.element == 0 ? 0.18 : 0.85))
    }
    .chartXAxis {
      AxisMarks(values: Array(stride(from: 0, through: 23, by: 3))) { value in
        AxisGridLine()
        AxisTick()
        if let hour = value.as(Int.self) {
          AxisValueLabel("\(hour)")
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine()
        AxisTick()
        if let seconds = value.as(Double.self) {
          AxisValueLabel(formatAxisListeningDuration(seconds))
        }
      }
    }
    .frame(minHeight: 170)
    .overlay {
      if secondsPerHour.allSatisfy({ $0 == 0 }) {
        StatsEmptyState(title: "No data", subtitle: "Once you've built up some history, the hour-of-day distribution will appear here.")
      }
    }
  }
}

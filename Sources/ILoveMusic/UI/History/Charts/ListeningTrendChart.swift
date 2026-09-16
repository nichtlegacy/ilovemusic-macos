import Charts
import SwiftUI

struct ListeningTrendChart: View {
  let dailyBuckets: [DailyBucket]
  let hourBuckets: [Double]
  let window: HistoryWindow

  var body: some View {
    if isHourly {
      if hourBuckets.allSatisfy({ $0 == 0 }) {
        StatsEmptyState(title: "Not enough data yet", subtitle: "Once you've listened to something today, the hourly trend will show up here.")
      } else {
        Chart(Array(hourBuckets.enumerated()), id: \.offset) { bucket in
          AreaMark(
            x: .value("Hour", bucket.offset),
            y: .value("Time", bucket.element / 3600)
          )
          .foregroundStyle(Color.accentColor.opacity(0.18))

          LineMark(
            x: .value("Hour", bucket.offset),
            y: .value("Time", bucket.element / 3600)
          )
          .foregroundStyle(Color.accentColor)
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
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
        .frame(minHeight: 170)
      }
    } else if dailyBuckets.isEmpty || dailyBuckets.allSatisfy({ $0.listenedSeconds == 0 }) {
      StatsEmptyState(title: "Not enough data yet", subtitle: "Once there's listening history in the selected range, your trend will appear here.")
    } else {
      Chart(dailyBuckets) { bucket in
        AreaMark(
          x: .value("Day", bucket.date),
          y: .value("Hours", bucket.listenedSeconds / 3600)
        )
        .foregroundStyle(Color.accentColor.opacity(0.18))

        LineMark(
          x: .value("Day", bucket.date),
          y: .value("Hours", bucket.listenedSeconds / 3600)
        )
        .foregroundStyle(Color.accentColor)
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 8)) { value in
          AxisGridLine()
          AxisTick()
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      }
      .frame(minHeight: 170)
    }
  }

  private var isHourly: Bool {
    if case .today = window {
      return true
    }
    return false
  }
}

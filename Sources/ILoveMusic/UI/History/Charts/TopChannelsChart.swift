import Charts
import SwiftUI

struct TopChannelsChart: View {
  let channels: [ChannelTotal]

  var body: some View {
    if channels.isEmpty {
      StatsEmptyState(title: "No channels played yet", subtitle: "Your top stations will appear here once you have enough history.")
    } else {
      Chart(channels) { channel in
        BarMark(
          x: .value("Time", channel.listenedSeconds),
          y: .value("Channel", channel.stationName)
        )
        .foregroundStyle(Color(hex: channel.accentHex))
      }
      .chartXAxis {
        AxisMarks(position: .bottom) { value in
          AxisGridLine()
          AxisTick()
          if let seconds = value.as(Double.self) {
            AxisValueLabel(formatAxisListeningDuration(seconds))
          }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading)
      }
      .frame(minHeight: 170)
    }
  }
}

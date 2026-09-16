import Charts
import SwiftUI

struct TopChannelsChart: View {
  let channels: [ChannelTotal]

  @State private var selectedIndex: Int?

  var body: some View {
    if channels.isEmpty {
      StatsEmptyState(title: "No channels played yet", subtitle: "Your top stations will appear here once you have enough history.")
    } else {
      Chart(Array(channels.enumerated()), id: \.element.id) { index, channel in
        BarMark(
          x: .value("Time", channel.listenedSeconds),
          y: .value("Channel", channel.stationName)
        )
        .foregroundStyle(Color(hex: channel.accentHex))
        .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.42)
        .cornerRadius(4)
        .accessibilityLabel(channel.stationName)
        .accessibilityValue("\(formatShortListeningDuration(channel.listenedSeconds)), \(channel.playCount) plays")
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
      .chartOverlay { proxy in
        GeometryReader { geometry in
          Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
              switch phase {
              case .active(let location):
                guard let plotFrame = proxy.plotFrame else { return }
                let frame = geometry[plotFrame]
                let plotY = location.y - frame.minY
                let stationName: String? = proxy.value(atY: plotY)
                let next = stationName.flatMap { name in
                  channels.firstIndex { $0.stationName == name }
                }
                if next != selectedIndex {
                  selectedIndex = next
                }
              case .ended:
                selectedIndex = nil
              }
            }
        }
      }
      .overlay(alignment: .topTrailing) {
        if let selectedIndex, channels.indices.contains(selectedIndex) {
          let channel = channels[selectedIndex]
          VStack(alignment: .leading, spacing: 2) {
            Text(channel.stationName)
              .font(.caption.bold())
            Text("\(formatShortListeningDuration(channel.listenedSeconds)) · \(channel.playCount) plays")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .padding(8)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .allowsHitTesting(false)
        }
      }
      .frame(height: max(170, CGFloat(channels.count) * 25))
      .accessibilityLabel("Top channels")
    }
  }
}

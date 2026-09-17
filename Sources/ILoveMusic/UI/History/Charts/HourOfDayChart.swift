import Charts
import SwiftUI

struct HourOfDayChart: View {
  let secondsPerHour: [Double]

  @State private var selectedHour: Int?
  @Environment(\.locale) private var locale

  var body: some View {
    Chart(Array(secondsPerHour.enumerated()), id: \.offset) { bucket in
      BarMark(
        x: .value(localized("Hour"), bucket.offset),
        y: .value(localized("Time"), bucket.element)
      )
      .foregroundStyle(.tint)
      .opacity(opacity(hour: bucket.offset, seconds: bucket.element))
      .cornerRadius(3)
      .accessibilityLabel(hourRange(bucket.offset))
      .accessibilityValue(formatShortListeningDuration(bucket.element, locale: locale))
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
          AxisValueLabel(formatAxisListeningDuration(seconds, locale: locale))
        }
      }
    }
    .chartYScale(domain: 0...max(60, (secondsPerHour.max() ?? 0) * 1.12))
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
              let next = ChartSelection.index(
                at: location.x - frame.minX,
                plotWidth: frame.width,
                count: secondsPerHour.count
              )
              if next != selectedHour {
                selectedHour = next
              }
            case .ended:
              selectedHour = nil
            }
          }
      }
    }
    .overlay(alignment: .topTrailing) {
      if let selectedHour, secondsPerHour.indices.contains(selectedHour) {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: "\(selectedHour):00–\((selectedHour + 1) % 24):00")
            .font(.caption.bold())
          Text(verbatim: formatShortListeningDuration(secondsPerHour[selectedHour], locale: locale))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
      }
    }
    .frame(height: 175)
    .accessibilityLabel(Text("Listening by hour", bundle: #bundle))
    .overlay {
      if secondsPerHour.allSatisfy({ $0 == 0 }) {
        StatsEmptyState(title: "No data", subtitle: "Once you've built up some history, the hour-of-day distribution will appear here.")
      }
    }
  }

  private func opacity(hour: Int, seconds: Double) -> Double {
    if seconds == 0 { return 0.12 }
    if selectedHour == nil || selectedHour == hour { return 0.9 }
    return 0.45
  }

  private func localized(_ value: String.LocalizationValue) -> String {
    String(localized: LocalizedStringResource(value, locale: locale, bundle: #bundle))
  }

  private func hourRange(_ hour: Int) -> String {
    String(
      localized: LocalizedStringResource(
        "\(hour):00 to \((hour + 1) % 24):00",
        locale: locale,
        bundle: #bundle,
        comment: "Accessible hour range in a listening chart."
      )
    )
  }
}

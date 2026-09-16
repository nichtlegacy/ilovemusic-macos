import Charts
import SwiftUI

struct ListeningTrendChart: View {
  let dailyBuckets: [DailyBucket]
  let hourBuckets: [Double]
  let window: HistoryWindow

  @State private var selectedIndex: Int?

  var body: some View {
    if isHourly {
      if hourBuckets.allSatisfy({ $0 == 0 }) {
        StatsEmptyState(title: "Not enough data yet", subtitle: "Once you've listened to something today, the hourly trend will show up here.")
      } else {
        let buckets = Array(hourBuckets.enumerated())
        Chart(buckets, id: \.offset) { bucket in
          AreaMark(
            x: .value("Hour", bucket.offset),
            y: .value("Time", bucket.element)
          )
          .foregroundStyle(.tint.opacity(0.12))

          LineMark(
            x: .value("Hour", bucket.offset),
            y: .value("Time", bucket.element)
          )
          .foregroundStyle(.tint)
          .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
          .accessibilityLabel("\(bucket.offset):00 to \((bucket.offset + 1) % 24):00")
          .accessibilityValue(formatShortListeningDuration(bucket.element))

          if selectedIndex == bucket.offset {
            RuleMark(x: .value("Selected hour", bucket.offset))
              .foregroundStyle(.secondary.opacity(0.5))
              .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
              .annotation(position: .top, alignment: annotationAlignment(for: bucket.offset, count: buckets.count)) {
                tooltip(title: "\(bucket.offset):00–\((bucket.offset + 1) % 24):00", seconds: bucket.element)
              }
            PointMark(
              x: .value("Selected hour", bucket.offset),
              y: .value("Selected time", bucket.element)
            )
            .symbolSize(42)
            .foregroundStyle(.tint)
          }
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
            if let seconds = value.as(Double.self) {
              AxisValueLabel(formatAxisListeningDuration(seconds))
            }
          }
        }
        .chartYScale(domain: 0...yMaximum(hourBuckets))
        .chartOverlay { proxy in
          hourlyHoverOverlay(proxy: proxy, count: buckets.count)
        }
        .frame(height: 180)
        .accessibilityLabel("Listening trend")
      }
    } else if dailyBuckets.isEmpty || dailyBuckets.allSatisfy({ $0.listenedSeconds == 0 }) {
      StatsEmptyState(title: "Not enough data yet", subtitle: "Once there's listening history in the selected range, your trend will appear here.")
    } else {
      Chart(Array(dailyBuckets.enumerated()), id: \.element.id) { index, bucket in
        AreaMark(
          x: .value("Day", bucket.date),
          y: .value("Time", bucket.listenedSeconds)
        )
        .foregroundStyle(.tint.opacity(0.12))

        LineMark(
          x: .value("Day", bucket.date),
          y: .value("Time", bucket.listenedSeconds)
        )
        .foregroundStyle(.tint)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .accessibilityLabel(bucket.date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityValue(formatShortListeningDuration(bucket.listenedSeconds))

        if selectedIndex == index {
          RuleMark(x: .value("Selected day", bucket.date))
            .foregroundStyle(.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, alignment: annotationAlignment(for: index, count: dailyBuckets.count)) {
              tooltip(
                title: bucket.date.formatted(date: .abbreviated, time: .omitted),
                seconds: bucket.listenedSeconds
              )
            }
          PointMark(
            x: .value("Selected day", bucket.date),
            y: .value("Selected time", bucket.listenedSeconds)
          )
          .symbolSize(42)
          .foregroundStyle(.tint)
        }
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 8)) { value in
          AxisGridLine()
          AxisTick()
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          if let seconds = value.as(Double.self) {
            AxisValueLabel(formatAxisListeningDuration(seconds))
          }
        }
      }
      .chartYScale(domain: 0...yMaximum(dailyBuckets.map(\.listenedSeconds)))
      .chartOverlay { proxy in
        dailyHoverOverlay(proxy: proxy)
      }
      .frame(height: 180)
      .accessibilityLabel("Listening trend")
    }
  }

  private var isHourly: Bool {
    if case .today = window {
      return true
    }
    return false
  }

  private func yMaximum(_ values: [Double]) -> Double {
    max(60, (values.max() ?? 0) * 1.12)
  }

  private func annotationAlignment(for index: Int, count: Int) -> Alignment {
    switch ChartSelection.edge(for: index, count: count) {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }

  private func tooltip(title: String, seconds: Double) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption.bold())
      Text(formatShortListeningDuration(seconds))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private func hourlyHoverOverlay(proxy: ChartProxy, count: Int) -> some View {
    GeometryReader { geometry in
      Rectangle()
        .fill(.clear)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
          switch phase {
          case .active(let location):
            guard let plotFrame = proxy.plotFrame else { return }
            let frame = geometry[plotFrame]
            let plotX = location.x - frame.minX
            let hour: Int? = proxy.value(atX: plotX)
            let next = hour.map { min(count - 1, max(0, $0)) }
            if next != selectedIndex {
              selectedIndex = next
            }
          case .ended:
            selectedIndex = nil
          }
        }
      }
    }

  private func dailyHoverOverlay(proxy: ChartProxy) -> some View {
    GeometryReader { geometry in
      Rectangle()
        .fill(.clear)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
          switch phase {
          case .active(let location):
            guard let plotFrame = proxy.plotFrame else { return }
            let frame = geometry[plotFrame]
            let plotX = location.x - frame.minX
            let date: Date? = proxy.value(atX: plotX)
            let next = date.flatMap { hoveredDate in
              dailyBuckets.enumerated().min {
                abs($0.element.date.timeIntervalSince(hoveredDate))
                  < abs($1.element.date.timeIntervalSince(hoveredDate))
              }?.offset
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
  }

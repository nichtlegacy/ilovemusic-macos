import SwiftUI

struct HeatmapSelection: Hashable {
  let row: Int
  let hour: Int

  func moving(rowDelta: Int, hourDelta: Int) -> Self {
    Self(
      row: min(6, max(0, row + rowDelta)),
      hour: min(23, max(0, hour + hourDelta))
    )
  }
}

struct WeekdayHourHeatmap: View {
  let matrix: [[Double]]

  private let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  private let rowLabelWidth: CGFloat = 28
  private let cellSpacing: CGFloat = 3

  @State private var selection: HeatmapSelection?
  @State private var hoveredSelection: HeatmapSelection?
  @FocusState private var isFocused: Bool

  private var effectiveSelection: HeatmapSelection? {
    hoveredSelection ?? selection
  }

  var body: some View {
    let maxValue = matrix.flatMap { $0 }.max() ?? 0

    GeometryReader { proxy in
      let availableWidth = max(0, proxy.size.width - rowLabelWidth - 8)
      let pitch = max(8, availableWidth / 24)
      let cellSize = max(5, min(15, pitch - cellSpacing))
      let gridWidth = (cellSize * 24) + (cellSpacing * 23)

      VStack(alignment: .leading, spacing: 9) {
        hourLabels(cellSize: cellSize, gridWidth: gridWidth)
        cells(maxValue: maxValue, cellSize: cellSize, gridWidth: gridWidth)

        HStack(spacing: 6) {
          Text("Less")
          ForEach([0.12, 0.35, 0.65, 1.0], id: \.self) { opacity in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .fill(.tint.opacity(opacity))
              .frame(width: 11, height: 11)
          }
          Text("More")
          Spacer()
          if let selection = effectiveSelection {
            Text(selectionDescription(selection))
              .lineLimit(1)
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(height: 168)
    .focusable()
    .focused($isFocused)
    .onKeyPress(.upArrow) { moveSelection(row: -1, hour: 0) }
    .onKeyPress(.downArrow) { moveSelection(row: 1, hour: 0) }
    .onKeyPress(.leftArrow) { moveSelection(row: 0, hour: -1) }
    .onKeyPress(.rightArrow) { moveSelection(row: 0, hour: 1) }
    .overlay {
      if maxValue == 0 {
        StatsEmptyState(title: "No data", subtitle: "The heatmap fills in as you listen more.")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Listening by weekday and hour")
    .accessibilityValue(effectiveSelection.map(selectionDescription) ?? "No cell selected")
    .accessibilityAdjustableAction { direction in
      adjustSelection(direction)
    }
  }

  private func hourLabels(cellSize: CGFloat, gridWidth: CGFloat) -> some View {
    HStack(alignment: .bottom, spacing: 8) {
      Color.clear.frame(width: rowLabelWidth, height: 1)
      HStack(spacing: cellSpacing) {
        ForEach(0..<24, id: \.self) { hour in
          Text([0, 6, 12, 18, 23].contains(hour) ? "\(hour)" : "")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
            .frame(width: cellSize, alignment: hour == 23 ? .trailing : .leading)
        }
      }
      .frame(width: gridWidth, alignment: .leading)
    }
  }

  private func cells(maxValue: Double, cellSize: CGFloat, gridWidth: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: cellSpacing) {
      ForEach(Array(matrix.enumerated()), id: \.offset) { rowIndex, row in
        HStack(spacing: 8) {
          Text(weekdayLabels[safe: rowIndex] ?? "")
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .frame(width: rowLabelWidth, alignment: .leading)

          HStack(spacing: cellSpacing) {
            ForEach(Array(row.enumerated()), id: \.offset) { hour, value in
              let coordinate = HeatmapSelection(row: rowIndex, hour: hour)
              Button {
                selection = coordinate
                isFocused = true
              } label: {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                  .fill(.tint.opacity(opacity(for: value, maxValue: maxValue)))
                  .overlay {
                    if effectiveSelection == coordinate {
                      RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.tint, lineWidth: 2)
                    }
                  }
                  .frame(width: cellSize, height: cellSize)
              }
              .buttonStyle(.plain)
              .focusable(false)
              .onHover { hovering in
                if hovering {
                  hoveredSelection = coordinate
                } else if hoveredSelection == coordinate {
                  hoveredSelection = nil
                }
              }
              .help(accessibilityLabel(for: coordinate, value: value))
              .accessibilityLabel(accessibilityLabel(for: coordinate, value: value))
              .accessibilityValue(formatShortListeningDuration(value))
            }
          }
          .frame(width: gridWidth, alignment: .leading)
        }
      }
    }
  }

  private func moveSelection(row rowDelta: Int, hour hourDelta: Int) -> KeyPress.Result {
    let current = effectiveSelection ?? HeatmapSelection(row: 0, hour: 0)
    hoveredSelection = nil
    selection = current.moving(rowDelta: rowDelta, hourDelta: hourDelta)
    return .handled
  }

  private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
    let current = effectiveSelection ?? HeatmapSelection(row: 0, hour: 0)
    hoveredSelection = nil
    let linearIndex = (current.row * 24) + current.hour
    let nextIndex: Int
    switch direction {
    case .increment:
      nextIndex = min(167, linearIndex + 1)
    case .decrement:
      nextIndex = max(0, linearIndex - 1)
    @unknown default:
      return
    }
    selection = HeatmapSelection(row: nextIndex / 24, hour: nextIndex % 24)
  }

  private func opacity(for value: Double, maxValue: Double) -> Double {
    guard maxValue > 0 else { return 0.08 }
    return max(0.10, min(1, value / maxValue))
  }

  private func selectionDescription(_ coordinate: HeatmapSelection) -> String {
    let value = matrix[safe: coordinate.row]?[safe: coordinate.hour] ?? 0
    return "\(weekdayLabels[safe: coordinate.row] ?? "") · \(coordinate.hour):00 · \(formatShortListeningDuration(value))"
  }

  private func accessibilityLabel(for coordinate: HeatmapSelection, value: Double) -> String {
    "\(weekdayLabels[safe: coordinate.row] ?? ""), \(coordinate.hour):00 to \((coordinate.hour + 1) % 24):00, \(formatShortListeningDuration(value))"
  }
}

private extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

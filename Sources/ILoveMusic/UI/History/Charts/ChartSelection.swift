import Foundation

enum ChartLabelEdge: Equatable {
  case leading
  case center
  case trailing
}

enum ChartSelection {
  static func index(at x: CGFloat, plotWidth: CGFloat, count: Int) -> Int? {
    guard count > 0, plotWidth > 0, x >= 0, x < plotWidth else { return nil }
    return min(count - 1, Int((x / plotWidth) * CGFloat(count)))
  }

  static func edge(for index: Int, count: Int) -> ChartLabelEdge {
    if index == 0 { return .leading }
    if index == count - 1 { return .trailing }
    return .center
  }
}

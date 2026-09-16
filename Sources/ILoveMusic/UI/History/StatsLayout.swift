import Foundation

enum StatsLayout {
  static let maximumContentWidth: CGFloat = 1180

  static func metricsColumns(for width: CGFloat) -> Int {
    if width >= 640 { return 4 }
    if width >= 480 { return 2 }
    return 1
  }

  static func supportingColumns(for width: CGFloat) -> Int {
    width >= 760 ? 2 : 1
  }

  static func rankingLimit(for width: CGFloat) -> Int {
    width >= 760 ? 8 : 5
  }

  static func showsPageEmptyState(eventCountInWindow: Int) -> Bool {
    eventCountInWindow == 0
  }
}

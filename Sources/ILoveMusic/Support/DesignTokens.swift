import CoreGraphics
import SwiftUI

/// Centralized visual constants for ILoveMusic.
///
/// Adopt these tokens where the same literal recurs across files (e.g. the
/// three footer button shells all use 26×22 + cornerRadius 5). Inline
/// literals stay acceptable for one-off, situational sizes — the goal is
/// consistency where it matters, not blanket replacement.
///
/// Phase 6.2 of the Swift Refactor Master Plan.
enum Spacing {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 6
  static let md: CGFloat = 8
  static let lg: CGFloat = 12
  static let xl: CGFloat = 16
}

enum CornerRadius {
  /// Quick chips (footer tooltips, hover backgrounds).
  static let xs: CGFloat = 4
  /// Footer buttons.
  static let sm: CGFloat = 5
  /// Station row, generic small surfaces.
  static let md: CGFloat = 6
  /// Hero play button, primary action chips.
  static let lg: CGFloat = 7
  /// Popover sections, settings cards.
  static let xl: CGFloat = 8
  /// Artwork tiles, app icon placeholder.
  static let xxl: CGFloat = 14
}

enum ControlSize {
  /// Footer-bar buttons (refresh, history, quit, settings).
  static let footerButton = CGSize(width: 26, height: 22)
  /// Compact popover action buttons (Restart, Website, favorite).
  static let popoverAction = CGSize(width: 26, height: 26)
  /// Primary main-row controls inside the hero (Play, Next, Shuffle).
  static let heroControl = CGSize(width: 32, height: 28)
  /// Station row total height.
  static let stationRow: CGFloat = 44
}

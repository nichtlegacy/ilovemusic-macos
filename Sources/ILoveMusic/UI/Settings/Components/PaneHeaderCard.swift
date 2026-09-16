import SwiftUI

/// Hero row at the top of the Discord and Stream Deck settings tabs.
///
/// Layout: 44×44 icon tile + title/subtitle stack + trailing `StatusBadge`.
/// Matches the legacy `DiscordCard` / `StreamDeckCard` look so existing users
/// see continuity.
@MainActor
struct PaneHeaderCard: View {
  let systemImage: String
  let iconColor: Color
  let iconFontSize: CGFloat
  let title: String
  let subtitle: String
  let badgeColor: Color
  let badgeLabel: String

  init(
    systemImage: String,
    iconColor: Color,
    iconFontSize: CGFloat = 24,
    title: String,
    subtitle: String,
    badgeColor: Color,
    badgeLabel: String
  ) {
    self.systemImage = systemImage
    self.iconColor = iconColor
    self.iconFontSize = iconFontSize
    self.title = title
    self.subtitle = subtitle
    self.badgeColor = badgeColor
    self.badgeLabel = badgeLabel
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: iconFontSize))
        .foregroundStyle(iconColor)
        .frame(width: 44, height: 44)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
      }
      Spacer()
      StatusBadge(color: badgeColor, label: badgeLabel)
    }
  }
}

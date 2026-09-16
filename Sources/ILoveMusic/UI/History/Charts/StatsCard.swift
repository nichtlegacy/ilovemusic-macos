import SwiftUI

struct StatsCard<Content: View>: View {
  let title: String
  var fullWidth = false
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.secondary)

      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: fullWidth ? 220 : 210, alignment: .top)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.regularMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
    )
  }
}

struct StatsEmptyState: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 8) {
      Spacer()
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

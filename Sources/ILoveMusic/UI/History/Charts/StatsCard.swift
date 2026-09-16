import SwiftUI

struct StatsSection<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      content()
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding(16)
    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
    }
  }
}

struct StatsSectionEmptyState: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 140)
  }
}

// Kept while individual charts migrate to the more explicit section-level name.
typealias StatsEmptyState = StatsSectionEmptyState

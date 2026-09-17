import SwiftUI

struct StatsSection<Content: View>: View {
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource?
  @ViewBuilder let content: () -> Content

  @Environment(\.locale) private var locale

  init(
    title: String.LocalizationValue,
    subtitle: String.LocalizationValue? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.title = LocalizedStringResource(title, bundle: #bundle)
    self.subtitle = subtitle.map { LocalizedStringResource($0, bundle: #bundle) }
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title.resolved(in: locale))
          .font(.headline)
        if let subtitle {
          Text(subtitle.resolved(in: locale))
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
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource

  @Environment(\.locale) private var locale

  init(title: String.LocalizationValue, subtitle: String.LocalizationValue) {
    self.title = LocalizedStringResource(title, bundle: #bundle)
    self.subtitle = LocalizedStringResource(subtitle, bundle: #bundle)
  }

  var body: some View {
    VStack(spacing: 8) {
      Text(title.resolved(in: locale))
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(subtitle.resolved(in: locale))
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 140)
  }
}

// Kept while individual charts migrate to the more explicit section-level name.
typealias StatsEmptyState = StatsSectionEmptyState

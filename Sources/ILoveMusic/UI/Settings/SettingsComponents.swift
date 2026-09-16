import AppKit
import SwiftUI

@MainActor
struct PreferenceToggleRow: View {
  let title: String
  let subtitle: String?
  @Binding var isOn: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 5.4) {
      Toggle(isOn: $isOn) {
        Text(title).font(.body)
      }
      .toggleStyle(.checkbox)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

@MainActor
struct SettingsBlock<Content: View>: View {
  let header: String?
  let contentSpacing: CGFloat
  @ViewBuilder let content: () -> Content

  init(_ header: String? = nil, contentSpacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
    self.header = header
    self.contentSpacing = contentSpacing
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let header, !header.isEmpty {
        Text(header)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
      }
      VStack(alignment: .leading, spacing: contentSpacing) {
        content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

@MainActor
struct DataRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value).foregroundStyle(.primary)
    }
    .font(.callout)
  }
}

@MainActor
struct PrefsScrollPane<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 16) {
        content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
  }
}

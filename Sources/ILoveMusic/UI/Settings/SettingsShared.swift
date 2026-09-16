import SwiftUI

/// Native toggle row for Settings Forms: title + description, macOS switch style.
@MainActor
struct SettingsToggle: View {
  let title: String
  let subtitle: String?
  @Binding var isOn: Bool

  init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
    self.title = title
    self.subtitle = subtitle
    self._isOn = isOn
  }

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .toggleStyle(.switch)
  }
}

/// Small status dot + label for LabeledContent rows (Discord, Stream Deck).
@MainActor
struct SettingsStatusDot: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(label)
        .foregroundStyle(.secondary)
    }
  }
}

extension View {
  @ViewBuilder
  func scrollEdgeEffectSoftIfAvailable() -> some View {
    if #available(macOS 26.0, *) {
      scrollEdgeEffectStyle(.soft, for: .all)
    } else {
      self
    }
  }

  /// Shared modifiers for every Settings detail Form.
  @ViewBuilder
  func settingsFormStyle() -> some View {
    self
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .contentMargins(.top, 8, for: .scrollContent)
  }
}

/// DisclosureGroup whose whole label row (not just the text) toggles.
@MainActor
struct SettingsDisclosureGroup<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
    self.title = title
    self.content = content
  }

  var body: some View {
    DisclosureGroup {
      content()
    } label: {
      HStack {
        Text(title)
        Spacer(minLength: 8)
      }
      .contentShape(Rectangle())
    }
  }
}

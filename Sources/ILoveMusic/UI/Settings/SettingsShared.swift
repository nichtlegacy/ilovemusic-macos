import AppKit
import SwiftUI

struct SettingsIconChip: View {
  let tab: SettingsTab

  var body: some View {
    Image(systemName: tab.icon)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.white)
      .accessibilityHidden(true)
      .frame(width: 20, height: 20)
      .background {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .fill(
            LinearGradient(
              colors: [tab.iconColor.opacity(0.78), tab.iconColor],
              startPoint: .top,
              endPoint: .bottom
            )
          )
      }
  }
}

struct SettingsRowLabel: View {
  let title: String
  let subtitle: String?

  init(_ title: String, subtitle: String? = nil) {
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

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
      SettingsRowLabel(title, subtitle: subtitle)
    }
    .toggleStyle(.switch)
  }
}

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
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }
}

struct SettingsVisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = .behindWindow
    view.state = .followsWindowActiveState
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.material = material
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

  @ViewBuilder
  func settingsFormStyle() -> some View {
    self
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .contentMargins(.top, 8, for: .scrollContent)
  }
}

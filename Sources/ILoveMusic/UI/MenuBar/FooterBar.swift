import AppKit
import SwiftUI

struct FooterBar: View {
  let appModel: AppModel

  var body: some View {
    HStack(spacing: 8) {
      RefreshButton(outcome: appModel.refreshOutcome) {
        Task { await appModel.refreshAll() }
      }

      if appModel.preferences.recordHistoryEnabled ?? true {
        FooterButton(
          systemImage: "clock.arrow.circlepath",
          help: LocalizedStringResource(
            "History & Stats",
            bundle: #bundle,
            comment: "Help text for the button that opens listening history and statistics."
          )
        ) {
          openHistoryWindow()
        }
      }

      Spacer()

      FooterButton(
        systemImage: "power",
        help: LocalizedStringResource(
          "Quit ILoveMusic (⌥⌘Q)",
          bundle: #bundle,
          comment: "Help text for the quit button, including its keyboard shortcut."
        )
      ) {
        NSApplication.shared.terminate(nil)
      }

      SettingsButton(appModel: appModel)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private func openHistoryWindow() {
    appModel.requestOpenHistoryWindow?()
  }
}

struct SettingsButton: View {
  let appModel: AppModel

  @State private var isHovering = false

  var body: some View {
    Button {
      appModel.requestOpenSettingsWindow?()
    } label: {
      Image(systemName: "gearshape")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: ControlSize.footerButton.width, height: ControlSize.footerButton.height)
        .background(
          RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovering = $0 }
    .help(Text("Settings", bundle: #bundle, comment: "Help text for the button that opens Settings."))
    .accessibilityLabel(Text("Settings", bundle: #bundle, comment: "Accessibility label for the button that opens Settings."))
  }
}

struct RefreshButton: View {
  let outcome: RefreshOutcome
  let action: () -> Void

  @State private var spinning: Bool = false
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: "arrow.clockwise")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: ControlSize.footerButton.width, height: ControlSize.footerButton.height)
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .animation(
          spinning
            ? .linear(duration: 0.9).repeatForever(autoreverses: false)
            : .easeOut(duration: 0.2),
          value: spinning
        )
        .background(
          RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
            .fill(background)
            .animation(.easeInOut(duration: 0.25), value: outcome)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovering = $0 }
    .help(Text(helpText))
    .accessibilityLabel(Text(helpText))
    .onChange(of: outcome, initial: true) { _, new in
      spinning = (new == .refreshing)
    }
  }

  private var tint: Color {
    switch outcome {
    case .success: return .green
    case .failed: return .red
    case .refreshing: return .primary
    case .idle: return .secondary
    }
  }

  private var background: Color {
    switch outcome {
    case .success: return Color.green.opacity(0.15)
    case .failed: return Color.red.opacity(0.15)
    default: return isHovering ? Color.primary.opacity(0.08) : .clear
    }
  }

  private var helpText: LocalizedStringResource {
    switch outcome {
    case .success:
      LocalizedStringResource("Refresh succeeded", bundle: #bundle, comment: "Help text after station data refreshed successfully.")
    case .failed:
      LocalizedStringResource(
        "Refresh failed — using cached data",
        bundle: #bundle,
        comment: "Help text after refreshing station data failed and cached data is shown."
      )
    case .refreshing:
      LocalizedStringResource("Refreshing…", bundle: #bundle, comment: "Help text while station data is refreshing.")
    case .idle:
      LocalizedStringResource("Refresh everything", bundle: #bundle, comment: "Help text for the button that refreshes all station data.")
    }
  }
}

struct FooterButton: View {
  let systemImage: String
  let help: LocalizedStringResource
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: ControlSize.footerButton.width, height: ControlSize.footerButton.height)
        .background(
          RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovering = $0 }
    .help(Text(help))
    .accessibilityLabel(Text(help))
  }
}

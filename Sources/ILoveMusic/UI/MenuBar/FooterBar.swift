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
        FooterButton(systemImage: "clock.arrow.circlepath", help: "History & Stats") {
          openHistoryWindow()
        }
      }

      Spacer()

      FooterButton(systemImage: "power", help: "Quit ILoveMusic (⌥⌘Q)") {
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
    .help("Settings")
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
    .help(helpText)
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

  private var helpText: String {
    switch outcome {
    case .success: return "Refresh succeeded"
    case .failed: return "Refresh failed — using cached data"
    case .refreshing: return "Refreshing…"
    case .idle: return "Refresh everything"
    }
  }
}

struct FooterButton: View {
  let systemImage: String
  let help: String
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
    .help(help)
  }
}

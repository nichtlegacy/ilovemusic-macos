import AppKit
import Carbon
import SwiftUI

/// A row that displays a single global hotkey and lets the user re-record it.
///
/// Interaction model:
///   - Tap the pill to enter recording mode. The pill fills with the accent
///     tint and shows live modifier feedback as the user holds keys.
///   - Press any non-modifier key with at least one modifier → that combo
///     becomes the new binding.
///   - Press Esc → clears the binding (sets it to `nil`, display "—").
///   - Click outside → cancels recording without changing anything.
///   - Reset button (↻) → restores the default for this slot.
///   - Trash button (⌫) → clears the binding.
///
/// Conflict detection: the row's `conflictWith` parameter receives the title
/// of another action that already uses this combo so the row can flag it.
@MainActor
struct HotkeyRecorderRow: View {
  let id: HotkeyID
  /// Current binding for this slot. `nil` means "no shortcut assigned".
  let binding: HotkeyBinding?
  /// Returns the title of an action that already uses `candidate`, or `nil`
  /// if the combo is free. The recorder uses this to colour the pill and to
  /// reject saves that would create a duplicate.
  let conflictForCandidate: (HotkeyBinding) -> String?
  let onSave: (HotkeyBinding?) -> Void
  /// Notified when recording starts/stops so the host can suspend the global
  /// Carbon hotkey listener for the duration.
  let onRecordingChanged: (Bool) -> Void

  /// Sentinel keyCode meaning "the user pressed Esc — clear this slot".
  fileprivate static let escapeSentinelKeyCode: UInt32 = .max

  @State private var isRecording = false
  @State private var conflictMessage: String?

  private var defaultBinding: HotkeyBinding {
    HotkeyBinding.defaultBinding(for: id)
  }

  var body: some View {
    HStack(spacing: 12) {
      Text(id.title)
      Spacer()
      pill
      Button { resetToDefault() } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .buttonStyle(.borderless)
      .help("Reset to default (\(defaultBinding.display))")
      .accessibilityLabel("Reset \(id.title) to default")
      .disabled(binding == defaultBinding && !isRecording)

      Button { clear() } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .help("Clear shortcut")
      .accessibilityLabel("Clear \(id.title) shortcut")
      .disabled(binding == nil && !isRecording)
    }
  }

  // MARK: - Pill

  @ViewBuilder
  private var pill: some View {
    if isRecording {
      RecordingPill(
        onCapture: { keyCode, rawModifierFlags in
          handleCapture(keyCode: keyCode, rawModifierFlags: rawModifierFlags)
        }
      )
    } else {
      Button {
        startRecording()
      } label: {
        Text(binding?.display ?? "—")
          .font(.system(.callout, design: .monospaced).weight(.medium))
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(pillBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
      }
      .buttonStyle(.plain)
      .help(helpText)
    }
  }

  private var pillBackground: AnyShapeStyle {
    if conflictMessage != nil {
      return AnyShapeStyle(Color.red.opacity(0.15))
    }
    return AnyShapeStyle(.quaternary)
  }

  private var helpText: String {
    if let conflictMessage { return conflictMessage }
    if binding == nil { return "Tap to record a shortcut" }
    return "Tap to re-record"
  }

  // MARK: - Recording lifecycle

  private func startRecording() {
    guard !isRecording else { return }
    isRecording = true
    onRecordingChanged(true)
  }

  private func stopRecording(saving newBinding: HotkeyBinding??) {
    isRecording = false
    onRecordingChanged(false)
    if let resolved = newBinding {
      // resolved is `HotkeyBinding?`. nil means "clear".
      onSave(resolved)
      recomputeConflict(for: resolved)
    }
  }

  private func handleCapture(keyCode: UInt32, rawModifierFlags: UInt) {
    let flags = NSEvent.ModifierFlags(rawValue: rawModifierFlags)

    if Int(keyCode) == kVK_Escape {
      stopRecording(saving: .some(nil))
      return
    }

    let modifiers = KeyCodeFormatter.carbonModifiers(from: flags)
    guard modifiers != 0 else {
      // Plain keypress without modifiers → ignore to avoid grabbing 'A'.
      return
    }

    let candidate = HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
    if let conflict = conflictForCandidate(candidate) {
      conflictMessage = "Conflicts with \(conflict)"
      // Stay in recording mode so the user can try again. The pill turns red.
      return
    }

    stopRecording(saving: .some(candidate))
  }

  private func clear() {
    onSave(nil)
    conflictMessage = nil
  }

  private func resetToDefault() {
    let candidate = defaultBinding
    conflictMessage = conflictForCandidate(candidate)
    onSave(candidate)
  }

  private func recomputeConflict(for candidate: HotkeyBinding?) {
    if let candidate {
      conflictMessage = conflictForCandidate(candidate)
    } else {
      conflictMessage = nil
    }
  }
}

/// Live recording pill — installs a local `NSEvent` monitor while visible
/// and shows the held modifier glyphs as live feedback.
@MainActor
private struct RecordingPill: View {
  /// Receives the captured key code and the raw modifier-flag rawValue.
  /// We avoid passing `NSEvent` directly because it's non-Sendable.
  let onCapture: (UInt32, UInt) -> Void

  @State private var monitor: Any?
  @State private var liveModifiers: NSEvent.ModifierFlags = []

  var body: some View {
    Text(displayText)
      .font(.system(.callout, design: .monospaced).weight(.medium))
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.accentColor.opacity(0.18))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
      )
      .onAppear { installMonitor() }
      .onDisappear { removeMonitor() }
  }

  private var displayText: String {
    let mods = KeyCodeFormatter.carbonModifiers(from: liveModifiers)
    let prefix = KeyCodeFormatter.modifierString(mods)
    if prefix.isEmpty {
      return "Press keys…"
    }
    return prefix + "…"
  }

  private func installMonitor() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
      // NSEvent is delivered on the main thread but isn't Sendable, so we
      // extract its scalar payload here and hop to MainActor with only
      // Sendable primitives.
      let type = event.type
      let keyCode = UInt32(event.keyCode)
      let rawModifiers = event.modifierFlags.rawValue
      MainActor.assumeIsolated {
        switch type {
        case .flagsChanged:
          liveModifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
        case .keyDown:
          onCapture(keyCode, rawModifiers)
        default:
          break
        }
      }
      // Swallow keyDown/flagsChanged so they don't fall through to the focused
      // text field. Other event types are unreachable given the match mask.
      return nil
    }
  }

  private func removeMonitor() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }
}

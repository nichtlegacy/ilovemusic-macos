import AppKit
import Foundation

/// Concentrates the imperative side effects that fire when user preferences
/// change: launch-at-login, global hotkeys, and Dock-icon activation policy.
///
/// `AppModel` still owns the persisted `UserPreferences` value and remains the
/// single observable root. This coordinator owns the *appliers* — the macOS
/// integrations that have to be poked when a preference flips.
///
/// Boundary:
///   - No state of its own beyond the two manager instances.
///   - No knowledge of `AppModel`. AppModel calls in with the new value.
///   - Hotkey handlers are owned here so the SwiftUI tree never sees the
///     `GlobalShortcutManager`.
@MainActor
final class PreferencesCoordinator {
  private let launchAtLoginManager: LaunchAtLoginManager
  private let globalShortcutManager: GlobalShortcutManager

  init(
    launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
    globalShortcutManager: GlobalShortcutManager = GlobalShortcutManager()
  ) {
    self.launchAtLoginManager = launchAtLoginManager
    self.globalShortcutManager = globalShortcutManager
  }

  /// Applies the persisted launch-at-login preference. Safe to call multiple
  /// times with the same value — `LaunchAtLoginManager` is idempotent.
  func applyLaunchAtLogin(_ enabled: Bool) -> LaunchAtLoginManager.Outcome {
    launchAtLoginManager.setEnabled(enabled)
  }

  /// What macOS actually has registered, regardless of the stored preference.
  var isLaunchAtLoginRegistered: Bool {
    launchAtLoginManager.isRegistered
  }

  /// Registers or tears down the system-wide hotkey listeners.
  ///
  /// When `enabled` is false the manager is fully unregistered so neither the
  /// Carbon event handler nor any individual hotkey ref stays alive.
  /// Returns the slots the system refused to register, so the settings UI can
  /// tell the user which shortcut is already taken.
  @discardableResult
  func applyHotkeyBindings(enabled: Bool, bindings: HotkeyBindings) -> Set<HotkeyID> {
    if enabled {
      return globalShortcutManager.register(bindings: bindings)
    }
    globalShortcutManager.unregister()
    return []
  }

  /// Temporarily releases all hotkeys so a `HotkeyRecorderRow` can observe
  /// raw key events without Carbon intercepting registered combos.
  func suspendGlobalHotkeys() {
    globalShortcutManager.unregister()
  }

  /// Flips between Dock-icon visible (`.regular`) and menu-bar-only
  /// (`.accessory`). The history window opens its own override via
  /// `AppModel.prepareForAuxiliaryWindowPresentation()`.
  ///
  /// Uses `NSApplication.shared` (not the `NSApp` implicitly-unwrapped
  /// global) so tests that haven't fully bootstrapped AppKit don't
  /// crash on a nil NSApp.
  func applyDockIcon(_ visible: Bool) {
    NSApplication.shared.setActivationPolicy(visible ? .regular : .accessory)
  }

  /// Wires the hotkey callbacks. Called once during `AppModel`
  /// background-loop setup so the closures keep `[weak self]` on the model.
  func setHotkeyHandlers(
    onTogglePlayback: @escaping () -> Void,
    onNextStation: @escaping () -> Void,
    onShuffleStation: @escaping () -> Void,
    onQuit: @escaping () -> Void
  ) {
    globalShortcutManager.setHandlers(
      onTogglePlayback: onTogglePlayback,
      onNextStation: onNextStation,
      onShuffleStation: onShuffleStation,
      onQuit: onQuit
    )
  }
}

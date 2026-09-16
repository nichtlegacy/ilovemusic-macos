import Carbon
import Foundation

/// Bridges user-configurable hotkeys to the Carbon `RegisterEventHotKey` API.
///
/// Each registered hotkey is identified by a `HotkeyID`; the slot maps to a
/// closure in `setHandlers(...)`. Re-registering replaces the existing
/// bindings atomically: existing refs are unregistered, the new mapping is
/// installed, the event handler is re-attached.
final class GlobalShortcutManager {
  private var hotKeyRefs: [HotkeyID: EventHotKeyRef] = [:]
  private(set) var failedRegistrations: Set<HotkeyID> = []
  private var eventHandler: EventHandlerRef?
  private var onTogglePlayback: (() -> Void)?
  private var onNextStation: (() -> Void)?
  private var onShuffleStation: (() -> Void)?
  private var onQuit: (() -> Void)?

  func setHandlers(
    onTogglePlayback: @escaping () -> Void,
    onNextStation: @escaping () -> Void,
    onShuffleStation: @escaping () -> Void,
    onQuit: @escaping () -> Void
  ) {
    self.onTogglePlayback = onTogglePlayback
    self.onNextStation = onNextStation
    self.onShuffleStation = onShuffleStation
    self.onQuit = onQuit
  }

  /// Replaces any previously registered hotkeys with `bindings`. A `HotkeyID`
  /// missing from `bindings` is treated as "no shortcut" — its action stays
  /// reachable from the in-app UI but won't fire from a system hotkey.
  /// Returns the slots whose combo `RegisterEventHotKey` refused, which happens
  /// when macOS or another app already owns it.
  @discardableResult
  func register(bindings: HotkeyBindings) -> Set<HotkeyID> {
    unregister()

    var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
      guard let event, let userData else { return noErr }
      let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
      var hotKeyID = EventHotKeyID()
      GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
      if let id = HotkeyID(rawValue: hotKeyID.id) {
        switch id {
        case .playPause: manager.onTogglePlayback?()
        case .nextStation: manager.onNextStation?()
        case .randomStation: manager.onShuffleStation?()
        case .quit: manager.onQuit?()
        }
      }
      return noErr
    }, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)

    for (id, binding) in bindings {
      registerHotKey(id: id, keyCode: binding.keyCode, modifiers: binding.modifiers)
    }

    return failedRegistrations
  }

  func unregister() {
    for ref in hotKeyRefs.values {
      UnregisterEventHotKey(ref)
    }
    hotKeyRefs.removeAll()
    failedRegistrations.removeAll()
    if let eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
  }

  /// Number of successfully registered Carbon hotkeys.
  var registeredCount: Int { hotKeyRefs.count }

  private func registerHotKey(id: HotkeyID, keyCode: UInt32, modifiers: UInt32) {
    let hotKeyID = EventHotKeyID(signature: OSType(0x494C4D53), id: id.rawValue)
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    if status == noErr, let ref {
      hotKeyRefs[id] = ref
    } else {
      // A system-reserved combo, or one another app grabbed first. Carbon
      // reports this only through the status code, so record it for the UI.
      failedRegistrations.insert(id)
    }
  }
}

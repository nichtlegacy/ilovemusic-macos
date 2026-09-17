import Carbon
import Foundation

/// Stable identifier for each user-configurable global hotkey.
///
/// Used both as the `EventHotKeyID.id` value on the Carbon side and as the
/// dictionary key in `HotkeyBindings`.
enum HotkeyID: UInt32, CaseIterable, Codable, Hashable {
  case playPause = 1
  case nextStation = 2
  case randomStation = 3
  case quit = 4

  var title: String {
    switch self {
    case .playPause: "Play / Pause"
    case .nextStation: "Next station"
    case .randomStation: "Random station"
    case .quit: "Quit"
    }
  }

  var titleResource: LocalizedStringResource {
    switch self {
    case .playPause: LocalizedStringResource("Play / Pause", bundle: #bundle, comment: "Global hotkey action name.")
    case .nextStation: LocalizedStringResource("Next station", bundle: #bundle, comment: "Global hotkey action name.")
    case .randomStation: LocalizedStringResource("Random station", bundle: #bundle, comment: "Global hotkey action name.")
    case .quit: LocalizedStringResource("Quit", bundle: #bundle, comment: "Global hotkey action name.")
    }
  }
}

/// User-defined keyboard shortcut for one global action.
///
/// Stored verbatim in `state.json`. The `display` is precomputed (rather than
/// rebuilt every render) so the settings UI can show it without depending on
/// the Carbon framework on the render path.
struct HotkeyBinding: Codable, Equatable, Hashable {
  /// Carbon `kVK_*` virtual keycode.
  var keyCode: UInt32
  /// Carbon modifier mask (`cmdKey | optionKey | controlKey | shiftKey`).
  var modifiers: UInt32
  /// Human-readable representation, e.g. `"⌥⌘P"`.
  var display: String

  init(keyCode: UInt32, modifiers: UInt32, display: String? = nil) {
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.display = display ?? KeyCodeFormatter.display(keyCode: keyCode, modifiers: modifiers)
  }

  static func defaultBinding(for id: HotkeyID) -> HotkeyBinding {
    let mods = UInt32(optionKey) | UInt32(cmdKey)
    switch id {
    case .playPause:
      return HotkeyBinding(keyCode: UInt32(kVK_ANSI_P), modifiers: mods)
    case .nextStation:
      return HotkeyBinding(keyCode: UInt32(kVK_ANSI_N), modifiers: mods)
    case .randomStation:
      return HotkeyBinding(keyCode: UInt32(kVK_ANSI_R), modifiers: mods)
    case .quit:
      return HotkeyBinding(keyCode: UInt32(kVK_ANSI_Q), modifiers: mods)
    }
  }
}

typealias HotkeyBindings = [HotkeyID: HotkeyBinding]

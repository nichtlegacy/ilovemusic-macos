import AppKit
import Carbon

/// Formats Carbon virtual key codes and modifier masks into human-readable
/// shortcut strings ("⌥⌘P", "⌃⇧F12", "⌘Esc").
///
/// All conversions happen here so the rest of the codebase never touches the
/// Carbon framework on the render path.
enum KeyCodeFormatter {

  /// Combined modifier + key glyph string, ready to render in the settings UI.
  static func display(keyCode: UInt32, modifiers: UInt32) -> String {
    modifierString(modifiers) + keyString(keyCode: keyCode)
  }

  /// Just the modifier glyphs, in the Apple-canonical order ⌃ ⌥ ⇧ ⌘.
  static func modifierString(_ modifiers: UInt32) -> String {
    var result = ""
    if modifiers & UInt32(controlKey) != 0 { result.append("⌃") }
    if modifiers & UInt32(optionKey)  != 0 { result.append("⌥") }
    if modifiers & UInt32(shiftKey)   != 0 { result.append("⇧") }
    if modifiers & UInt32(cmdKey)     != 0 { result.append("⌘") }
    return result
  }

  /// Returns the rendered glyph for a Carbon virtual key code.
  static func keyString(keyCode: UInt32) -> String {
    if let named = namedKeys[Int(keyCode)] {
      return named
    }
    if let mapped = uppercasedCharacter(forKeyCode: keyCode) {
      return mapped
    }
    return "Key \(keyCode)"
  }

  // MARK: - NSEvent → Carbon bridging

  /// Bridges NSEvent's modifier flags into the Carbon mask used by
  /// `RegisterEventHotKey`.
  static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var mods: UInt32 = 0
    if flags.contains(.command)  { mods |= UInt32(cmdKey) }
    if flags.contains(.option)   { mods |= UInt32(optionKey) }
    if flags.contains(.control)  { mods |= UInt32(controlKey) }
    if flags.contains(.shift)    { mods |= UInt32(shiftKey) }
    return mods
  }

  // MARK: - Internals

  private static let namedKeys: [Int: String] = [
    kVK_Return:           "↩",
    kVK_Tab:              "⇥",
    kVK_Space:            "Space",
    kVK_Delete:           "⌫",
    kVK_Escape:           "Esc",
    kVK_ForwardDelete:    "⌦",
    kVK_LeftArrow:        "←",
    kVK_RightArrow:       "→",
    kVK_DownArrow:        "↓",
    kVK_UpArrow:          "↑",
    kVK_Home:             "↖",
    kVK_End:              "↘",
    kVK_PageUp:           "⇞",
    kVK_PageDown:         "⇟",
    kVK_ANSI_KeypadEnter: "⌤",
    kVK_F1:               "F1",
    kVK_F2:               "F2",
    kVK_F3:               "F3",
    kVK_F4:               "F4",
    kVK_F5:               "F5",
    kVK_F6:               "F6",
    kVK_F7:               "F7",
    kVK_F8:               "F8",
    kVK_F9:               "F9",
    kVK_F10:              "F10",
    kVK_F11:              "F11",
    kVK_F12:              "F12",
    kVK_F13:              "F13",
    kVK_F14:              "F14",
    kVK_F15:              "F15",
  ]

  /// Uses the current keyboard layout to translate a virtual key code into a
  /// printable character, mirroring how AppKit labels menu shortcuts.
  private static func uppercasedCharacter(forKeyCode keyCode: UInt32) -> String? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data

    var deadKeyState: UInt32 = 0
    var charBuffer = [UniChar](repeating: 0, count: 4)
    var actualLength = 0

    let status = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
      guard let baseAddress = rawBuffer.baseAddress else { return errSecAllocate }
      let layoutPointer = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)
      return UCKeyTranslate(
        layoutPointer,
        UInt16(keyCode),
        UInt16(kUCKeyActionDisplay),
        0,
        UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysBit),
        &deadKeyState,
        charBuffer.count,
        &actualLength,
        &charBuffer
      )
    }

    guard status == noErr, actualLength > 0 else { return nil }
    let string = String(utf16CodeUnits: charBuffer, count: actualLength)
    return string.uppercased()
  }
}

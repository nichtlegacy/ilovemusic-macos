import AppKit

enum MenuBarIcon {
  static func image() -> NSImage {
    brandedTemplate()
  }

  private static func brandedTemplate() -> NSImage {
    let size = NSSize(width: 22, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13.5, weight: .black),
        .foregroundColor: NSColor.black,
        .kern: -0.5
      ]
      let str = NSAttributedString(string: "I♥", attributes: attrs)
      let textSize = str.size()
      let origin = NSPoint(
        x: ((rect.width - textSize.width) / 2).rounded(),
        y: ((rect.height - textSize.height) / 2 - 0.5).rounded()
      )
      str.draw(at: origin)
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = AppIdentity.displayName
    return image
  }
}

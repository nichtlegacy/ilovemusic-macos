import AppKit
import Foundation
import SwiftUI

extension String {
  var normalizedStationKey: String {
    folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: "♥", with: "love")
      .replacingOccurrences(of: "&", with: "and")
      .replacingOccurrences(of: "+", with: "plus")
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "_", with: "")
      .lowercased()
  }

  var htmlDecoded: String {
    guard let data = data(using: .utf8) else { return self }
    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue
    ]
    return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? self
  }
}

extension Color {
  init(hex: String, fallback: Color = .orange) {
    let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
      self = fallback
      return
    }

    let red = Double((value >> 16) & 0xff) / 255
    let green = Double((value >> 8) & 0xff) / 255
    let blue = Double(value & 0xff) / 255
    self = Color(red: red, green: green, blue: blue)
  }
}

func relativeLuminance(hex: String) -> Double {
  let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
    return 0.5
  }
  let r = Double((value >> 16) & 0xff) / 255
  let g = Double((value >> 8) & 0xff) / 255
  let b = Double(value & 0xff) / 255
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

extension Date {
  var shortTimeOrDateTime: String {
    formatted(date: .abbreviated, time: .shortened)
  }
}

import SwiftUI

func tintedStationName(_ name: String, accent: Color) -> AttributedString {
  var attr = AttributedString(name)
  if let range = attr.range(of: "♥") {
    attr[range].foregroundColor = accent
  }
  return attr
}

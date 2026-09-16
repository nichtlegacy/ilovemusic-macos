import AVKit
import AppKit
import SwiftUI

struct AirPlayPicker: NSViewRepresentable {
  func makeNSView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.isRoutePickerButtonBordered = false
    view.setRoutePickerButtonColor(.secondaryLabelColor, for: .normal)
    view.setRoutePickerButtonColor(.labelColor, for: .active)
    view.toolTip = "AirPlay…"
    return view
  }

  func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}

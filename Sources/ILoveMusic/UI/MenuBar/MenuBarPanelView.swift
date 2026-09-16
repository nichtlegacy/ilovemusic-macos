import SwiftUI

/// Root view rendered inside the menu-bar popover.
///
/// Composition only: the actual layout work lives in the dedicated subview
/// files — `HeroSection`, `StationsScrollView`, `FooterBar`,
/// `StationRow`, `StationDetailPopover`.
struct MenuBarPanelView: View {
  let appModel: AppModel
  let playbackController: PlaybackController

  var body: some View {
    ZStack {
      VisualEffectView(material: .popover, blendingMode: .behindWindow)

      VStack(spacing: 0) {
        HeroSection(appModel: appModel, playbackController: playbackController)

        Divider().opacity(0.35)

        StationsScrollView(appModel: appModel)

        Divider().opacity(0.35)

        FooterBar(appModel: appModel)
      }
    }
    .frame(width: 380, height: 640)
  }
}

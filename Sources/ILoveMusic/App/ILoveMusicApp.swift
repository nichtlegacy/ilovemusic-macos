import AppKit
import SwiftUI

@main
struct ILoveMusicApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(appModel: appDelegate.appModel)
    }
  }
}

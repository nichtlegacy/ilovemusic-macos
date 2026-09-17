import AppKit
import SwiftUI

@main
enum ILoveMusicLauncher {
  @MainActor
  static func main() {
    let language = AppStateStore().load().preferences.effectiveAppLanguage
    AppLocalization.configureProcessLanguage(language)
    ILoveMusicApp.main()
  }
}

struct ILoveMusicApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button(
          AppLocalization.string(
            LocalizedStringResource(
              "Settings…",
              bundle: #bundle,
              comment: "Application-menu command that opens Settings."
            ),
            language: appDelegate.appModel.activeLanguage
          )
        ) {
          appDelegate.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}

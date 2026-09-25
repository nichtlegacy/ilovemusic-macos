import AppKit

/// Plain AppKit entry point. The app used to run through a SwiftUI `App`
/// whose only scene was a placeholder `Settings { EmptyView() }`. Newer macOS
/// releases open an app's sole scene on launch, so every start (including
/// launch at login) showed that empty window. All windows are AppKit-owned
/// anyway, so there is no SwiftUI scene left to open.
@main
enum ILoveMusicLauncher {
  @MainActor private static var appDelegate: AppDelegate?

  @MainActor
  static func main() {
    let language = AppStateStore().load().preferences.effectiveAppLanguage
    AppLocalization.configureProcessLanguage(language)

    let app = NSApplication.shared
    // NSApplication holds its delegate weakly.
    let delegate = AppDelegate()
    appDelegate = delegate
    app.delegate = delegate
    app.run()
  }
}

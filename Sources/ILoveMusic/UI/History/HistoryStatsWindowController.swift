import AppKit
import SwiftUI

@MainActor
final class HistoryStatsWindowController: NSWindowController, NSWindowDelegate {
  static let defaultSize = NSSize(width: 1040, height: 760)
  static let minimumSize = NSSize(width: 760, height: 560)

  private let appModel: AppModel
  private let selection: HistoryStatsSelection

  init(appModel: AppModel) {
    let selection = HistoryStatsSelection()
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    self.appModel = appModel
    self.selection = selection

    window.title = AppLocalization.string(
      AppIdentity.historyWindowTitleResource,
      language: appModel.activeLanguage
    )
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.toolbarStyle = .unified
    window.contentMinSize = Self.minimumSize
    window.identifier = NSUserInterfaceItemIdentifier("history-stats")
    window.contentViewController = NSHostingController(
      rootView: HistoryStatsRootView(appModel: appModel, selection: selection)
        .environment(\.locale, appModel.activeLanguage.resolvedLocale)
    )
    window.isReleasedWhenClosed = false

    super.init(window: window)
    window.delegate = self
    window.setFrameAutosaveName("history-stats")
    if !window.setFrameUsingName("history-stats") {
      window.center()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    appModel.prepareForAuxiliaryWindowPresentation()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_ notification: Notification) {
    Task { @MainActor [weak self] in
      self?.appModel.restoreAccessoryPolicyIfNeeded()
    }
  }
}

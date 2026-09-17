import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  static let defaultSize = NSSize(width: 880, height: 620)
  static let minimumSize = NSSize(width: 800, height: 540)

  private let appModel: AppModel
  private let selection: SettingsSelection

  init(appModel: AppModel) {
    let selection = SettingsSelection()
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    let rootView = SettingsView(
      appModel: appModel,
      selection: selection,
      onSelectionChange: { [weak window] tab in
        window?.title = AppLocalization.string(tab.titleResource, language: appModel.activeLanguage)
      }
    )

    self.appModel = appModel
    self.selection = selection

    window.title = AppLocalization.string(selection.tab.titleResource, language: appModel.activeLanguage)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .visible
    window.titlebarSeparatorStyle = .none
    window.contentMinSize = Self.minimumSize
    window.identifier = NSUserInterfaceItemIdentifier("settings-window")
    window.contentViewController = NSHostingController(rootView: rootView)
    window.isReleasedWhenClosed = false

    super.init(window: window)

    window.delegate = self
    window.setFrameAutosaveName("settings-window")
    if !window.setFrameUsingName("settings-window") {
      window.center()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show(tab: SettingsTab? = nil) {
    if let tab {
      selection.tab = tab
    }

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

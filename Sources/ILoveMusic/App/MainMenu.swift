import AppKit

/// Builds the application menu bar. It is only visible while Settings or
/// History temporarily switch the app to `.regular`, but it still has to carry
/// the standard key equivalents: ⌘, and ⌘Q, plus the Edit commands text fields
/// rely on for ⌘C/⌘V and the Window commands for ⌘W/⌘M.
@MainActor
enum MainMenu {
  static func make(language: AppLanguage, settingsTarget: AnyObject, settingsAction: Selector) -> NSMenu {
    func localized(_ resource: LocalizedStringResource) -> String {
      AppLocalization.string(resource, language: language)
    }

    let mainMenu = NSMenu()

    let appMenu = NSMenu()
    let settingsItem = NSMenuItem(
      title: localized(
        LocalizedStringResource(
          "Settings…",
          bundle: #bundle,
          comment: "Application-menu command that opens Settings."
        )
      ),
      action: settingsAction,
      keyEquivalent: ","
    )
    settingsItem.target = settingsTarget
    appMenu.addItem(settingsItem)
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: localized(
        LocalizedStringResource(
          "Hide \(AppIdentity.displayName)",
          bundle: #bundle,
          comment: "Application-menu command that hides the app."
        )
      ),
      action: #selector(NSApplication.hide(_:)),
      keyEquivalent: "h"
    )
    let hideOthers = appMenu.addItem(
      withTitle: localized(
        LocalizedStringResource("Hide Others", bundle: #bundle, comment: "Application-menu command that hides other apps.")
      ),
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    )
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    appMenu.addItem(
      withTitle: localized(
        LocalizedStringResource("Show All", bundle: #bundle, comment: "Application-menu command that shows all hidden apps.")
      ),
      action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: ""
    )
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: localized(
        LocalizedStringResource(
          "Quit \(AppIdentity.displayName)",
          bundle: #bundle,
          comment: "Context-menu action that quits the app."
        )
      ),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    addSubmenu(appMenu, title: AppIdentity.displayName, to: mainMenu)

    let editMenu = NSMenu(
      title: localized(LocalizedStringResource("Edit", bundle: #bundle, comment: "Title of the Edit menu."))
    )
    editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Undo", bundle: #bundle, comment: "Edit-menu command.")),
      action: Selector(("undo:")),
      keyEquivalent: "z"
    )
    let redo = editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Redo", bundle: #bundle, comment: "Edit-menu command.")),
      action: Selector(("redo:")),
      keyEquivalent: "z"
    )
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Cut", bundle: #bundle, comment: "Edit-menu command.")),
      action: #selector(NSText.cut(_:)),
      keyEquivalent: "x"
    )
    editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Copy", bundle: #bundle, comment: "Edit-menu command.")),
      action: #selector(NSText.copy(_:)),
      keyEquivalent: "c"
    )
    editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Paste", bundle: #bundle, comment: "Edit-menu command.")),
      action: #selector(NSText.paste(_:)),
      keyEquivalent: "v"
    )
    editMenu.addItem(
      withTitle: localized(LocalizedStringResource("Select All", bundle: #bundle, comment: "Edit-menu command.")),
      action: #selector(NSText.selectAll(_:)),
      keyEquivalent: "a"
    )
    addSubmenu(editMenu, title: editMenu.title, to: mainMenu)

    let windowMenu = NSMenu(
      title: localized(LocalizedStringResource("Window", bundle: #bundle, comment: "Title of the Window menu."))
    )
    windowMenu.addItem(
      withTitle: localized(LocalizedStringResource("Minimize", bundle: #bundle, comment: "Window-menu command.")),
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    )
    windowMenu.addItem(
      withTitle: localized(LocalizedStringResource("Close", bundle: #bundle, comment: "Window-menu command.")),
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    addSubmenu(windowMenu, title: windowMenu.title, to: mainMenu)
    NSApp.windowsMenu = windowMenu

    return mainMenu
  }

  private static func addSubmenu(_ submenu: NSMenu, title: String, to mainMenu: NSMenu) {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = submenu
    mainMenu.addItem(item)
  }
}

import AppKit
import Observation
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let playbackController: PlaybackController
  let appModel: AppModel
  let updaterManager = UpdaterManager.shared

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var controlServer: ControlServer?
  private weak var historyWindow: NSWindow?
  private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppDelegate")

  override init() {
    let playbackController = PlaybackController()
    self.playbackController = playbackController
    self.appModel = AppModel(playbackController: playbackController)
    super.init()
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    logger.notice("launch: version=\(version, privacy: .public) build=\(build, privacy: .public) policy=accessory")

    installStatusItem()
    installPopover()
    observeMenuBarAppearance()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDeactivation),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWindowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: nil
    )
    Task { await appModel.bootstrapIfNeeded() }
    appModel.requestOpenHistoryWindow = { [weak self] in
      self?.openHistoryWindow()
    }

    let server = ControlServer(delegate: appModel, diagnosticsStore: appModel.controlDiagnosticsStore)
    server.onRuntimeStatusChange = { [weak appModel] status in
      Task { @MainActor [weak appModel] in
        appModel?.updateControlRuntimeStatus(status)
      }
    }
    server.start()
    self.controlServer = server
    logger.info("control server start requested")

    updaterManager.willPresentUpdateUI = { [weak appModel] in
      appModel?.prepareForAuxiliaryWindowPresentation()
    }
    updaterManager.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    logger.notice("terminating")
    appModel.historyRecorder.closeOpenEvent(reason: .quit)
    appModel.flushPendingPersistence()
    controlServer?.stop()
    appModel.discordManager.stop()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  @objc private func handleAppDeactivation() {
    if popover?.isShown == true {
      popover?.performClose(nil)
    }
  }

  @objc private func handleWindowWillClose(_ notification: Notification) {
    if let window = notification.object as? NSWindow, window === historyWindow {
      historyWindow = nil
    }

    DispatchQueue.main.async { [weak self] in
      self?.appModel.restoreAccessoryPolicyIfNeeded()
    }
  }

  func togglePopover() {
    guard let popover, let button = statusItem?.button else { return }
    if popover.isShown {
      popover.performClose(nil)
    } else {
      // Show first, then activate. If we activate before show(), AppKit briefly
      // hands the system menu bar to ILoveMusic (an .accessory app has no real
      // menus, so the menu bar appears to "hide") before the popover panel
      // claims key focus. Showing first means the popover panel already owns
      // focus by the time we tell AppKit we're active.
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      if let panel = popover.contentViewController?.view.window {
        // Mark the popover panel as ancillary so AppKit doesn't treat it as a
        // main application window that should drive the menu bar.
        panel.collectionBehavior.insert([.transient, .ignoresCycle])
        panel.makeKey()
      }
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func installStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.target = self
      button.action = #selector(handleStatusItemClick(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    statusItem = item
    refreshStatusItemAppearance()
  }

  private func installPopover() {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    popover.contentSize = NSSize(width: 380, height: 640)
    let panel = MenuBarPanelView(appModel: appModel, playbackController: playbackController)
    let host = NSHostingController(rootView: panel)
    host.view.frame = CGRect(x: 0, y: 0, width: 380, height: 640)
    popover.contentViewController = host
    self.popover = popover
  }

  @objc private func handleStatusItemClick(_ sender: Any?) {
    guard let event = NSApp.currentEvent else {
      togglePopover()
      return
    }
    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      togglePopover()
    }
  }

  private func showContextMenu() {
    guard let item = statusItem else { return }
    let menu = NSMenu()

    // 1. Current Station and Song
    if let station = appModel.activeStation {
      let stationItem = NSMenuItem(title: station.displayName, action: nil, keyEquivalent: "")
      stationItem.isEnabled = false
      stationItem.image = menuSymbol("antenna.radiowaves.left.and.right")
      menu.addItem(stationItem)

      if let md = appModel.activeMetadata, (!md.artist.isEmpty || !md.title.isEmpty) {
        let songStr = [md.artist, md.title].filter { !$0.isEmpty }.joined(separator: " - ")
        let songItem = NSMenuItem(title: songStr, action: nil, keyEquivalent: "")
        songItem.isEnabled = false
        songItem.image = menuSymbol("music.note")
        menu.addItem(songItem)
      } else {
        let noSongItem = NSMenuItem(title: "Not on air right now", action: nil, keyEquivalent: "")
        noSongItem.isEnabled = false
        noSongItem.image = menuSymbol("music.note")
        menu.addItem(noSongItem)
      }
    } else {
      let noStationItem = NSMenuItem(title: "No station playing", action: nil, keyEquivalent: "")
      noStationItem.isEnabled = false
      noStationItem.image = menuSymbol("speaker.slash")
      menu.addItem(noStationItem)
    }

    menu.addItem(.separator())

    // 2. Playback controls
    let isPlaying = playbackController.state.phase == .playing
    let playPause = NSMenuItem(
      title: isPlaying ? "Pause" : "Play",
      action: #selector(menuTogglePlayback),
      keyEquivalent: ""
    )
    playPause.image = menuSymbol(isPlaying ? "pause.fill" : "play.fill")
    menu.addItem(playPause)

    let nextItem = NSMenuItem(title: "Next Station", action: #selector(menuNextStation), keyEquivalent: "")
    nextItem.image = menuSymbol("forward.end.fill")
    menu.addItem(nextItem)

    let randomItem = NSMenuItem(title: "Random Station", action: #selector(menuRandomStation), keyEquivalent: "")
    randomItem.image = menuSymbol("shuffle")
    menu.addItem(randomItem)

    menu.addItem(.separator())

    // 3. App Actions
    let panelShown = popover?.isShown == true
    let toggleItem = NSMenuItem(
      title: panelShown ? "Hide Panel" : "Show Panel",
      action: #selector(menuTogglePopover),
      keyEquivalent: ""
    )
    toggleItem.image = menuSymbol(panelShown ? "eye.slash" : "eye")
    menu.addItem(toggleItem)

    let refreshItem = NSMenuItem(title: "Refresh", action: #selector(menuRefresh), keyEquivalent: "")
    refreshItem.image = menuSymbol("arrow.clockwise")
    menu.addItem(refreshItem)

    let historyItem = NSMenuItem(title: "History & Stats…", action: #selector(menuOpenHistory), keyEquivalent: "")
    historyItem.image = menuSymbol("clock.arrow.circlepath")
    menu.addItem(historyItem)

    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
    settingsItem.image = menuSymbol("gearshape")
    menu.addItem(settingsItem)

    let updateItem = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(menuCheckForUpdates),
      keyEquivalent: ""
    )
    updateItem.image = menuSymbol("arrow.down.circle")
    menu.addItem(updateItem)

    menu.addItem(.separator())

    // 4. Quit
    let quitItem = NSMenuItem(title: "Quit \(AppIdentity.displayName)", action: #selector(menuQuit), keyEquivalent: "q")
    quitItem.image = menuSymbol("power")
    menu.addItem(quitItem)

    for entry in menu.items where entry.action != nil {
      entry.target = self
    }
    item.menu = menu
    item.button?.performClick(nil)
    item.menu = nil
  }

  private func menuSymbol(_ name: String) -> NSImage? {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
    return image?.withSymbolConfiguration(config)
  }

  @objc private func menuTogglePopover() { togglePopover() }
  @objc private func menuTogglePlayback() { Task { await appModel.togglePlayback() } }
  @objc private func menuNextStation() { Task { await appModel.playNextStation() } }
  @objc private func menuRandomStation() { Task { await appModel.playRandomStation() } }
  @objc private func menuRefresh() { Task { await appModel.refreshAll() } }
  @objc private func menuOpenHistory() {
    if let requestOpenHistoryWindow = appModel.requestOpenHistoryWindow {
      requestOpenHistoryWindow()
    } else {
      togglePopover()
    }
  }
  @objc private func menuOpenSettings() {
    if #available(macOS 14.0, *) {
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }
  @objc private func menuCheckForUpdates() { updaterManager.checkForUpdates() }
  @objc private func menuQuit() { NSApp.terminate(nil) }

  private func observeMenuBarAppearance() {
    withObservationTracking { [appModel] in
      _ = appModel.activeStation?.displayName
      _ = appModel.activeStation?.accentHex
      _ = appModel.activePlaybackPhase
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.refreshStatusItemAppearance()
        self?.observeMenuBarAppearance()
      }
    }
  }

  private func refreshStatusItemAppearance() {
    guard let button = statusItem?.button else { return }
    button.image = MenuBarIcon.image()
    button.attributedTitle = NSAttributedString(string: "")
    button.imagePosition = .imageOnly
    button.toolTip = appModel.activeStation?.displayName ?? AppIdentity.displayName
  }

  private func openHistoryWindow() {
    appModel.prepareForAuxiliaryWindowPresentation()

    if let historyWindow {
      historyWindow.makeKeyAndOrderFront(nil)
      return
    }

    let rootView = HistoryStatsRootView(appModel: appModel)
    let hostingController = NSHostingController(rootView: rootView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: 820),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = AppIdentity.historyWindowTitle
    window.identifier = NSUserInterfaceItemIdentifier("history-stats")
    window.setFrameAutosaveName("history-stats")
    window.contentMinSize = NSSize(width: 900, height: 640)
    window.contentViewController = hostingController
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)

    self.historyWindow = window
  }
}

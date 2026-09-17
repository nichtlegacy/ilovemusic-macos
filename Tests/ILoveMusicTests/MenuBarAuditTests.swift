import AppKit
import Testing
@testable import ILoveMusic

/// Regression coverage for the menu-bar station-list click interceptor.
///
/// The interceptor installs an app-wide local `NSEvent` monitor. Because the
/// menu-bar popover is a reused `.transient` NSPopover whose hosting view tree
/// can outlive a close, the monitor lifecycle must follow actual window
/// presence (`viewDidMoveToWindow`) instead of relying solely on
/// `dismantleNSView`. This test exercises the window attach/detach path to
/// ensure it stays crash-free and idempotent — in particular the
/// `window == nil` teardown branch added to `viewDidMoveToWindow`.
@MainActor
@Test
func interceptViewMonitorLifecycleFollowsWindowPresence() {
  let view = StationListInterceptView()

  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 380, height: 640),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
  )

  // Attach -> should start monitoring without crashing.
  window.contentView?.addSubview(view)
  view.viewDidMoveToWindow()

  // Detach -> should tear the monitor down via the window == nil branch.
  view.removeFromSuperview()
  view.viewDidMoveToWindow()

  // Re-attach -> should restart cleanly (monitor was nil after detach).
  window.contentView?.addSubview(view)
  view.viewDidMoveToWindow()

  // Detaching again must be safe and idempotent.
  view.removeFromSuperview()
  view.viewDidMoveToWindow()
  view.viewDidMoveToWindow()
}

@Test
func contextMenuTitlesResolveInGermanAndPreserveMetadata() {
  let text = MenuBarContextMenuText(language: .german)
  let stationName = "I LOVE RADIO"
  let songLine = "Artist — Track"
  let titles = text.allTitles(
    stationName: stationName,
    songLine: songLine,
    isPlaying: false,
    panelShown: false
  )

  #expect(titles.contains(stationName))
  #expect(titles.contains(songLine))
  #expect(titles.contains("Wiedergeben"))
  #expect(titles.contains("Nächster Sender"))
  #expect(titles.contains("Zufälliger Sender"))
  #expect(titles.contains("Einstellungen…"))
  #expect(titles.contains("ILoveMusic beenden"))
}

@Test
func contextMenuTitlesResolveInEnglish() {
  let titles = MenuBarContextMenuText(language: .english).allTitles(
    stationName: nil,
    songLine: nil,
    isPlaying: true,
    panelShown: true
  )

  #expect(titles.contains("No station playing"))
  #expect(titles.contains("Pause"))
  #expect(titles.contains("Hide Panel"))
  #expect(titles.contains("Check for Updates…"))
}

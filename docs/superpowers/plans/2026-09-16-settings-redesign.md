# CodexBar-inspired Settings implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ILoveMusic's current Settings scene with a compact CodexBar-inspired window that has seven focused panes and keeps all existing preferences compatible.

**Architecture:** An AppKit `NSWindowController` owns one resizable Settings window and hosts a SwiftUI root view. The root uses a fixed material sidebar and grouped detail forms. Existing `AppModel` bindings remain the only path for changing application preferences.

**Tech stack:** Swift 6.2, SwiftUI, AppKit, Observation, Swift Testing, Sparkle

---

## File map

Create these files:

- `Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift`: window creation, frame restoration, activation, and presentation.
- `Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift`: sidebar rows, symbol chips, footer, and material background.
- `Sources/ILoveMusic/UI/Settings/Panes/DiscordPane.swift`: Discord preferences without diagnostic logs.
- `Sources/ILoveMusic/UI/Settings/Panes/StreamDeckPane.swift`: Stream Deck status without diagnostic logs.
- `Sources/ILoveMusic/UI/Settings/Panes/AdvancedPane.swift`: cache actions, diagnostics, and both logs.
- `Sources/ILoveMusic/UI/Settings/Panes/AboutPane.swift`: app identity, Sparkle controls, and links.
- `Tests/ILoveMusicTests/SettingsNavigationTests.swift`: tab order, persisted selection fallback, and window configuration.

Modify these files:

- `Sources/ILoveMusic/App/ILoveMusicApp.swift`: replace the visible SwiftUI Settings scene with the standard Command-comma command.
- `Sources/ILoveMusic/App/AppDelegate.swift`: own and open the Settings controller.
- `Sources/ILoveMusic/UI/MenuBar/FooterBar.swift`: replace `SettingsLink` with the shared Settings action.
- `Sources/ILoveMusic/UI/History/HistoryListView.swift`: replace `SettingsLink` with the shared Settings action.
- `Sources/ILoveMusic/UI/Settings/SettingsView.swift`: seven-pane routing and the custom two-column shell.
- `Sources/ILoveMusic/UI/Settings/SettingsShared.swift`: reusable row labels, form style, icon chip, and visual-effect wrapper.
- `Sources/ILoveMusic/UI/Settings/Panes/DataPane.swift`: keep catalog and listening-history controls only.
- `Sources/ILoveMusic/UI/Settings/Components/LogPanel.swift`: compact bounded diagnostic rows.
- `README.md`: update the Settings table and screenshot description.

Delete this file after its contents have moved:

- `Sources/ILoveMusic/UI/Settings/Panes/IntegrationsPane.swift`

## Task 1: Define stable Settings navigation

**Files:**
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`
- Create: `Tests/ILoveMusicTests/SettingsNavigationTests.swift`

- [ ] **Step 1: Write the failing navigation tests**

Add a suite that fixes the public order and fallback behavior:

```swift
import Testing
@testable import ILoveMusic

@MainActor
@Suite("Settings navigation")
struct SettingsNavigationTests {
  @Test
  func tabsHaveStableOrder() {
    #expect(SettingsTab.allCases == [
      .general, .playback, .discord, .streamDeck, .data, .advanced, .about,
    ])
  }

  @Test
  func unknownPersistedSelectionFallsBackToGeneral() {
    #expect(SettingsTab.persistedValue("discord") == .discord)
    #expect(SettingsTab.persistedValue("removed-pane") == .general)
    #expect(SettingsTab.persistedValue(nil) == .general)
  }

  @Test
  func selectionPersistsChanges() throws {
    let name = "SettingsNavigationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }

    let selection = SettingsSelection(defaults: defaults)
    #expect(selection.tab == .general)
    selection.tab = .streamDeck
    #expect(defaults.string(forKey: SettingsSelection.storageKey) == "streamDeck")
    #expect(SettingsSelection(defaults: defaults).tab == .streamDeck)
  }
}
```

- [ ] **Step 2: Run the new suite and confirm it fails**

Run: `rtk swift test --filter SettingsNavigationTests`

Expected: compilation fails because the new cases and `persistedValue` do not exist.

- [ ] **Step 3: Expand `SettingsTab` without changing preference storage**

Use this shape in `SettingsView.swift`:

```swift
enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
  case general
  case playback
  case discord
  case streamDeck
  case data
  case advanced
  case about

  var id: Self { self }

  static func persistedValue(_ rawValue: String?) -> Self {
    rawValue.flatMap(Self.init(rawValue:)) ?? .general
  }
}
```

Add exhaustive `title`, `icon`, and `iconColor` properties. Use `gearshape`, `play.circle.fill`, `bubble.left.and.bubble.right.fill`, `rectangle.3.group.fill`, `externaldrive.fill`, `wrench.and.screwdriver.fill`, and `info.circle.fill`. Use semantic or restrained system colors rather than custom hex values.

Import `Observation` and add the small observable selection owner beside the enum:

```swift
@MainActor
@Observable
final class SettingsSelection {
  static let storageKey = "settings.selectedTab"

  private let defaults: UserDefaults
  var tab: SettingsTab {
    didSet { defaults.set(tab.rawValue, forKey: Self.storageKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.tab = SettingsTab.persistedValue(defaults.string(forKey: Self.storageKey))
  }
}
```

- [ ] **Step 4: Run the suite and confirm it passes**

Run: `rtk swift test --filter SettingsNavigationTests`

Expected: the two tests pass.

- [ ] **Step 5: Commit the navigation contract**

```bash
git add Sources/ILoveMusic/UI/Settings/SettingsView.swift Tests/ILoveMusicTests/SettingsNavigationTests.swift
git commit -m "test(settings): define navigation contract"
```

## Task 2: Add the AppKit Settings window

**Files:**
- Create: `Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/ILoveMusic/App/AppDelegate.swift`
- Modify: `Sources/ILoveMusic/App/ILoveMusicApp.swift`
- Test: `Tests/ILoveMusicTests/SettingsNavigationTests.swift`

- [ ] **Step 1: Add a failing window-configuration test**

```swift
import AppKit

@Test
func settingsWindowUsesTheExpectedChrome() throws {
  let fixture = try makeSettingsTestModel()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let controller = SettingsWindowController(appModel: fixture.model)
  let window = try #require(controller.window)

  #expect(window.styleMask.contains(.fullSizeContentView))
  #expect(window.styleMask.contains(.resizable))
  #expect(window.contentMinSize == NSSize(width: 800, height: 540))
  #expect(window.frameAutosaveName == "settings-window")
}
```

Add `makeSettingsTestModel()` beside the tests. It should create a UUID-named temporary support directory and an immediate `AppStateStore`, matching `SettingsBindingTests`.

```swift
private func makeSettingsTestModel() throws -> (model: AppModel, directory: URL) {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let store = AppStateStore(supportDirectoryURL: directory, writeMode: .immediate)
  return (AppModel(playbackController: PlaybackController(), stateStoreOverride: store), directory)
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `rtk swift test --filter SettingsNavigationTests`

Expected: compilation fails because `SettingsWindowController` is missing.

- [ ] **Step 3: Implement the controller**

Create a `@MainActor final class SettingsWindowController: NSWindowController, NSWindowDelegate` with:

```swift
static let defaultSize = NSSize(width: 880, height: 620)
static let minimumSize = NSSize(width: 800, height: 540)

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
    onSelectionChange: { [weak window] tab in window?.title = tab.title }
  )
  self.appModel = appModel
  self.selection = selection
  window.title = selection.tab.title
  window.titlebarAppearsTransparent = true
  window.titleVisibility = .visible
  window.titlebarSeparatorStyle = .none
  window.contentMinSize = Self.minimumSize
  window.setFrameAutosaveName("settings-window")
  window.contentViewController = NSHostingController(rootView: rootView)
  window.isReleasedWhenClosed = false
  super.init(window: window)
  window.delegate = self
  if !window.setFrameUsingName("settings-window") { window.center() }
}
```

Expose `show(tab:)`, update the root selection when a tab is supplied, call `appModel.prepareForAuxiliaryWindowPresentation()`, and call `showWindow(nil)`, `makeKeyAndOrderFront(nil)`, and `NSApp.activate(ignoringOtherApps: true)`. On close, call `appModel.restoreAccessoryPolicyIfNeeded()` on the next main-actor turn.

Do not create a global singleton. `AppDelegate` owns one controller so its lifetime matches the application.

- [ ] **Step 4: Route every app-level Settings command to the controller**

Add this to `AppDelegate`:

```swift
private lazy var settingsWindowController = SettingsWindowController(appModel: appModel)

func openSettings(tab: SettingsTab? = nil) {
  popover?.performClose(nil)
  settingsWindowController.show(tab: tab)
}
```

Change `menuOpenSettings()` to call `openSettings()`. In `ILoveMusicApp`, keep a minimal `Settings { EmptyView() }` scene and replace the app-settings command:

```swift
.commands {
  CommandGroup(replacing: .appSettings) {
    Button("Settings…") { appDelegate.openSettings() }
      .keyboardShortcut(",", modifiers: .command)
  }
}
```

- [ ] **Step 5: Run the focused and full test suites**

Run: `rtk swift test --filter SettingsNavigationTests`

Expected: the suite passes.

Run: `rtk swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit the window shell**

```bash
git add Sources/ILoveMusic/App/ILoveMusicApp.swift Sources/ILoveMusic/App/AppDelegate.swift Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift Tests/ILoveMusicTests/SettingsNavigationTests.swift
git commit -m "feat(settings): add dedicated settings window"
```

## Task 3: Build the CodexBar-inspired shell

**Files:**
- Create: `Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsShared.swift`

- [ ] **Step 1: Add shared visual components**

Add a `SettingsIconChip` with a 20 by 20 rounded rectangle, an 11-point semibold white SF Symbol, a 5-point corner radius, and a restrained vertical gradient derived from `tab.iconColor`.

Add a `SettingsRowLabel`:

```swift
struct SettingsRowLabel: View {
  let title: String
  let subtitle: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
      if let subtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
```

Update `SettingsToggle` to use `SettingsRowLabel`. Add an `NSVisualEffectViewRepresentable` that takes `.sidebar` or `.windowBackground`, uses `.behindWindow`, and follows the active state.

- [ ] **Step 2: Implement the fixed sidebar**

`SettingsSidebar` takes `@Binding var selection: SettingsTab`. Its `List` contains only the seven tabs and uses `.listStyle(.sidebar)`, `.scrollContentBackground(.hidden)`, eight-point horizontal insets, and `Label`-equivalent rows built from `SettingsIconChip` plus text.

Place the app icon, `AppIdentity.displayName`, and version in a footer below the `List`, separated by a hairline. The footer must not participate in selection or scrolling.

- [ ] **Step 3: Replace `NavigationSplitView` with a simple two-column root**

Use:

```swift
HStack(spacing: 0) {
  SettingsSidebar(selection: $selection)
    .frame(width: 220)
  Divider()
  detailView
    .frame(maxWidth: 780, maxHeight: .infinity, alignment: .topLeading)
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

Accept the controller-owned `SettingsSelection` and bind the sidebar to `selection.tab`. Remove the custom sidebar toggle and optional-selection fallback. Call the controller's `onSelectionChange` closure whenever the tab changes so the native window title stays current.

- [ ] **Step 4: Compile before adding the new panes**

For this commit, route the four panes that do not exist yet to `Text(tab.title)` so the switch stays exhaustive. Tasks 4 through 6 replace every stub before release verification.

Run: `rtk swift build`

Expected: build succeeds.

- [ ] **Step 5: Commit the shell**

```bash
git add Sources/ILoveMusic/UI/Settings/SettingsView.swift Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift Sources/ILoveMusic/UI/Settings/SettingsShared.swift Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift
git commit -m "feat(settings): add material sidebar shell"
```

## Task 4: Restore focused Discord and Stream Deck panes

**Files:**
- Create: `Sources/ILoveMusic/UI/Settings/Panes/DiscordPane.swift`
- Create: `Sources/ILoveMusic/UI/Settings/Panes/StreamDeckPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`
- Delete: `Sources/ILoveMusic/UI/Settings/Panes/IntegrationsPane.swift`

- [ ] **Step 1: Move Discord controls into their own form**

Use two sections: `Connection` for status and the master switch, then `Rich Presence` for the four child toggles and Application ID. Apply `.disabled(!appModel.discordEnabled)` and reduced opacity to the complete child group, including the text field. Keep the existing inline `.error` label.

Do not move the connection log into this pane.

- [ ] **Step 2: Move Stream Deck status into its own form**

Use a `Status` section for bridge status, handshake, last request, and last issue. Put the bridge explanation in the section footer. Reuse the current recency and error calculations without adding timers or new service state.

Do not move the connection log into this pane.

- [ ] **Step 3: Route both tabs and remove the combined pane**

Replace the temporary `Text` routes in the detail switch with `DiscordPane(appModel:)` and `StreamDeckPane(appModel:)`. Delete `IntegrationsPane.swift` only after both replacements compile.

- [ ] **Step 4: Build and run preference tests**

Run: `rtk swift build && rtk swift test --filter SettingsBindingTests`

Expected: build succeeds and all Settings binding tests pass.

- [ ] **Step 5: Commit the split**

```bash
git add Sources/ILoveMusic/UI/Settings
git commit -m "refactor(settings): split integration panes"
```

## Task 5: Separate Data and Advanced operations

**Files:**
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/DataPane.swift`
- Create: `Sources/ILoveMusic/UI/Settings/Panes/AdvancedPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Components/LogPanel.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`

- [ ] **Step 1: Reduce Data to catalog and history**

Keep the current `Catalog` and `History` sections, including the reset confirmation. Remove cache, updates, diagnostics, and About content. Do not change `resetListeningHistory()` or its destructive confirmation text.

- [ ] **Step 2: Add Advanced maintenance and diagnostics**

Create sections named `Maintenance`, `Catalog diagnostics`, `Discord log`, and `Stream Deck log`. Put Refresh, Clear Catalog Cache, and Clear Artwork Cache on separate labeled rows so localized labels cannot collide.

Track small inline feedback with:

```swift
@State private var maintenanceStatus: String?
```

Set it to `"Refresh complete"`, `"Catalog cache cleared"`, or `"Artwork cache cleared"` after the corresponding existing operation finishes. Show the result as caption text with a checkmark. Do not add alerts or persistent state.

- [ ] **Step 3: Make logs compact and bounded**

Keep the existing severity filter and clear action. Render at most ten newest matching entries. Replace each large rounded card with a compact row containing time, area, severity dot, and a wrapping message. Separate rows with `Divider()` and keep one short footer showing the visible and persisted limits.

- [ ] **Step 4: Route Advanced and compile**

Add `AdvancedPane(appModel:)` to the detail switch.

Run: `rtk swift build`

Expected: build succeeds.

- [ ] **Step 5: Commit the separation**

```bash
git add Sources/ILoveMusic/UI/Settings/Panes/DataPane.swift Sources/ILoveMusic/UI/Settings/Panes/AdvancedPane.swift Sources/ILoveMusic/UI/Settings/Components/LogPanel.swift Sources/ILoveMusic/UI/Settings/SettingsView.swift
git commit -m "refactor(settings): separate data and diagnostics"
```

## Task 6: Restore About and correct update dependencies

**Files:**
- Create: `Sources/ILoveMusic/UI/Settings/Panes/AboutPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`

- [ ] **Step 1: Add the free-standing About hero**

The top row contains the 92-point app icon, `AppIdentity.displayName`, version, build, and the one-sentence project description. Give only this row a transparent list-row background. Do not restore the previous hover scaling or accent shadow.

- [ ] **Step 2: Add grouped Updates and Links sections**

Move `UpdatesSection` from `DataPane` into `AboutPane`. Disable and fade the background-download toggle whenever `automaticallyChecksForUpdates` is false:

```swift
.disabled(!updater.automaticallyChecksForUpdates)
.opacity(updater.automaticallyChecksForUpdates ? 1 : 0.5)
```

Keep the last-check value and manual Check for Updates button. Add native `Link` rows for GitHub and `ILOVEMUSIC.DE`, followed by the copyright footer.

- [ ] **Step 3: Route About and compile**

Add `AboutPane()` to the detail switch.

Run: `rtk swift build`

Expected: build succeeds.

- [ ] **Step 4: Commit About**

```bash
git add Sources/ILoveMusic/UI/Settings/Panes/AboutPane.swift Sources/ILoveMusic/UI/Settings/Panes/DataPane.swift Sources/ILoveMusic/UI/Settings/SettingsView.swift
git commit -m "feat(settings): restore focused about pane"
```

## Task 7: Route in-app Settings buttons

**Files:**
- Modify: `Sources/ILoveMusic/App/AppModel.swift`
- Modify: `Sources/ILoveMusic/App/AppDelegate.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/FooterBar.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryListView.swift`

- [ ] **Step 1: Add the same request seam used by History**

Add this non-persisted callback to `AppModel` near `requestOpenHistoryWindow`:

```swift
var requestOpenSettingsWindow: (() -> Void)?
```

Assign it during `applicationDidFinishLaunching`:

```swift
appModel.requestOpenSettingsWindow = { [weak self] in
  self?.openSettings()
}
```

- [ ] **Step 2: Replace both `SettingsLink` controls**

In `FooterBar`, pass `appModel` into `SettingsButton` and use a plain `Button` whose action calls `appModel.requestOpenSettingsWindow?()`.

In `HistoryEmptyState`, replace `showsSettingsLink` with an optional `openSettings` closure. At the call site, pass `{ appModel.requestOpenSettingsWindow?() }` when history recording is disabled. Keep the existing button label `Open Settings…`.

- [ ] **Step 3: Verify there are no visible Settings links left**

Run: `rtk rg -n "SettingsLink|showSettingsWindow|showPreferencesWindow" Sources/ILoveMusic`

Expected: no matches.

- [ ] **Step 4: Run the full test suite**

Run: `rtk swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit routing**

```bash
git add Sources/ILoveMusic/App Sources/ILoveMusic/UI/MenuBar/FooterBar.swift Sources/ILoveMusic/UI/History/HistoryListView.swift
git commit -m "fix(settings): route every entry point to one window"
```

## Task 8: Build, inspect, and document the result

**Files:**
- Modify: `README.md`
- Replace after visual approval: `docs/screenshots/settings.png`

- [ ] **Step 1: Update the README Settings table**

List the seven panes and their actual contents. Remove claims about six tabs and remove the old locations for updates, diagnostics, Discord logs, and Stream Deck logs.

- [ ] **Step 2: Run static and unit verification**

Run:

```bash
rtk git diff --check
rtk swift test
rtk swift build -c release
```

Expected: no whitespace errors, all tests pass, and the release build completes.

- [ ] **Step 3: Build the real app bundle**

Run: `rtk ./scripts/build-app.sh`

Expected: `.build/ILoveMusic.app` passes the script's deep code-sign verification.

- [ ] **Step 4: Perform the live window checks**

Open the built app and verify:

- Settings opens from the menu-bar menu, the footer gear, History's empty state, and Command-comma.
- The window opens at 880 by 620 points on first launch and never shrinks below 800 by 540.
- All seven panes select correctly and the last pane returns after close and reopen.
- Window size and position return after close and reopen.
- Light and dark appearances keep readable materials and semantic colors.
- Discord child controls, including Application ID, disable when Discord is off.
- Background downloads disable when automatic update checks are off.
- Both logs remain compact with ten entries.
- Cache actions show inline completion text.
- Closing the last auxiliary window returns the app to accessory activation policy.

- [ ] **Step 5: Capture the approved Settings screenshot**

Replace `docs/screenshots/settings.png` with a screenshot of the General pane at the default window size. Do this only after the live checks pass.

- [ ] **Step 6: Commit documentation and screenshot**

```bash
git add README.md docs/screenshots/settings.png
git commit -m "docs: update settings overview"
```

- [ ] **Step 7: Review final scope**

Run: `rtk git status --short` and `rtk git log --oneline b22f968..HEAD`.

Expected: only Settings, entry-point, focused test, README, and screenshot changes appear. No generated `.build` output or unrelated work is staged.

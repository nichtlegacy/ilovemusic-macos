# Native History and Stats Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rigid card dashboard with a responsive, overview-first macOS History and Stats window while preserving all existing history and aggregation behavior.

**Architecture:** A dedicated AppKit window controller owns the auxiliary window and a small persisted navigation model. SwiftUI renders a native toolbar, responsive overview sections, compact semantic panels, and interactive charts; pure layout and hit-testing helpers keep resizing and pointer behavior deterministic and testable. `PlayHistoryStats` and `StatsSnapshotProvider` remain unchanged as the domain source of truth.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Charts, Observation, Swift Testing

---

## File map

Create these files:

- `Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift`: window ownership, chrome, sizing, restoration, and presentation.
- `Sources/ILoveMusic/UI/History/StatsLayout.swift`: pure responsive column and ranking-density decisions.
- `Sources/ILoveMusic/UI/History/Charts/ChartSelection.swift`: pure horizontal hit testing and edge-label alignment.
- `Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift`: four compact overview metrics in one shared surface.
- `Tests/ILoveMusicTests/HistoryStatsUITests.swift`: navigation persistence, window configuration, responsive layout, and chart geometry contracts.

Modify these files:

- `Sources/ILoveMusic/App/AppDelegate.swift`: own and show the new window controller instead of constructing the window inline.
- `Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift`: persisted navigation and native toolbar content.
- `Sources/ILoveMusic/UI/History/StatsView.swift`: overview-first order, page-level empty state, maximum content width, and adaptive sections.
- `Sources/ILoveMusic/UI/History/HistoryListView.swift`: native search/filter controls, compact rows, and consistent English copy.
- `Sources/ILoveMusic/UI/History/Charts/StatsCard.swift`: restrained reusable section surface without fixed minimum heights.
- `Sources/ILoveMusic/UI/History/Charts/ListeningTrendChart.swift`: explicit domains, pointer selection, tooltip, and accessibility.
- `Sources/ILoveMusic/UI/History/Charts/TopChannelsChart.swift`: adaptive row count, pointer selection, and accessibility.
- `Sources/ILoveMusic/UI/History/Charts/GenreDonutChart.swift`: adaptive legend placement and accessible segments.
- `Sources/ILoveMusic/UI/History/Charts/HourOfDayChart.swift`: compact axes, pointer selection, and accessibility.
- `Sources/ILoveMusic/UI/History/Charts/WeekdayHourHeatmap.swift`: width-derived geometry, selection, keyboard navigation, legend, and accessibility.
- `Sources/ILoveMusic/UI/History/Charts/TopArtistsCard.swift`: compact ranking rows.
- `Sources/ILoveMusic/UI/History/Charts/TopSongsCard.swift`: compact ranking rows.
- `README.md`: describe and show the verified native workspace.
- `docs/screenshots/stats.png`: replace only after runtime visual verification.

Delete after replacement:

- `Sources/ILoveMusic/UI/History/Charts/StatCardsRow.swift`: superseded by `StatsSummaryStrip`.

The work is one cohesive UI project: the window shell, responsive Stats page, and History destination share navigation, size constraints, language, and runtime verification. Do not split domain-statistics changes into this plan.

## Task 1: Lock navigation and responsive-layout contracts

**Files:**
- Create: `Sources/ILoveMusic/UI/History/StatsLayout.swift`
- Create: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift`

- [ ] **Step 1: Write failing tests for persistence and breakpoints**

Create `Tests/ILoveMusicTests/HistoryStatsUITests.swift`:

```swift
import AppKit
import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("History and Stats UI")
struct HistoryStatsUITests {
  @Test
  func unknownPersistedDestinationFallsBackToHistory() throws {
    let name = "HistoryStatsUITests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }

    defaults.set("removed", forKey: HistoryStatsSelection.destinationKey)
    let selection = HistoryStatsSelection(defaults: defaults)

    #expect(selection.destination == .history)
    selection.destination = .stats
    #expect(defaults.string(forKey: HistoryStatsSelection.destinationKey) == "stats")
  }

  @Test
  func responsiveLayoutUsesStableBreakpoints() {
    #expect(StatsLayout.metricsColumns(for: 700) == 4)
    #expect(StatsLayout.metricsColumns(for: 560) == 2)
    #expect(StatsLayout.metricsColumns(for: 420) == 1)
    #expect(StatsLayout.supportingColumns(for: 900) == 2)
    #expect(StatsLayout.supportingColumns(for: 620) == 1)
    #expect(StatsLayout.rankingLimit(for: 900) == 8)
    #expect(StatsLayout.rankingLimit(for: 620) == 5)
  }
}
```

- [ ] **Step 2: Run the suite and confirm the new contracts fail**

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: compilation fails because `HistoryStatsSelection` and `StatsLayout` do not exist.

- [ ] **Step 3: Add persisted destination state**

Replace the enum and local tab state at the top of `HistoryStatsRootView.swift` with:

```swift
import AppKit
import Observation
import SwiftUI

enum HistoryStatsTab: String, CaseIterable, Hashable, Identifiable {
  case history
  case stats

  var id: Self { self }
  var title: String { self == .history ? "History" : "Stats" }
  var symbol: String { self == .history ? "clock.arrow.circlepath" : "chart.bar.xaxis" }
}

@MainActor
@Observable
final class HistoryStatsSelection {
  static let destinationKey = "historyStats.selectedDestination"

  private let defaults: UserDefaults
  var destination: HistoryStatsTab {
    didSet { defaults.set(destination.rawValue, forKey: Self.destinationKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.destination = defaults.string(forKey: Self.destinationKey)
      .flatMap(HistoryStatsTab.init(rawValue:)) ?? .history
  }
}
```

Change `HistoryStatsRootView` to accept `let selection: HistoryStatsSelection`. Do not change the visible custom tab bar yet; bind it to `selection.destination` so the next task can replace the shell without combining persistence and window work.

- [ ] **Step 4: Add the pure responsive helper**

Create `Sources/ILoveMusic/UI/History/StatsLayout.swift`:

```swift
import Foundation

enum StatsLayout {
  static let maximumContentWidth: CGFloat = 1180

  static func metricsColumns(for width: CGFloat) -> Int {
    if width >= 640 { return 4 }
    if width >= 480 { return 2 }
    return 1
  }

  static func supportingColumns(for width: CGFloat) -> Int {
    width >= 760 ? 2 : 1
  }

  static func rankingLimit(for width: CGFloat) -> Int {
    width >= 760 ? 8 : 5
  }
}
```

- [ ] **Step 5: Run the focused suite**

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: all persistence and breakpoint tests pass.

- [ ] **Step 6: Commit the state and layout contract**

```bash
git add Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift Sources/ILoveMusic/UI/History/StatsLayout.swift Tests/ILoveMusicTests/HistoryStatsUITests.swift
git commit -m "test(stats): define navigation and layout contracts"
```

## Task 2: Build the native auxiliary window and toolbar

**Files:**
- Create: `Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift`
- Modify: `Sources/ILoveMusic/App/AppDelegate.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift`
- Test: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`

- [ ] **Step 1: Add a failing window configuration test**

Add this test and fixture to `HistoryStatsUITests`:

```swift
@Test
func historyWindowUsesNativeResizableChrome() throws {
  let fixture = try makeModel()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let controller = HistoryStatsWindowController(appModel: fixture.model)
  let window = try #require(controller.window)

  #expect(HistoryStatsWindowController.defaultSize == NSSize(width: 1040, height: 760))
  #expect(window.contentMinSize == NSSize(width: 760, height: 560))
  #expect(window.styleMask.contains(.fullSizeContentView))
  #expect(window.styleMask.contains(.resizable))
  #expect(window.toolbarStyle == .unified)
  #expect(window.frameAutosaveName == "history-stats")
}

private func makeModel() throws -> (model: AppModel, directory: URL) {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let store = AppStateStore(supportDirectoryURL: directory, writeMode: .immediate)
  return (AppModel(playbackController: PlaybackController(), stateStoreOverride: store), directory)
}
```

- [ ] **Step 2: Run the test and confirm the controller is missing**

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: compilation fails because `HistoryStatsWindowController` does not exist.

- [ ] **Step 3: Add the dedicated controller**

Create `HistoryStatsWindowController.swift` with this structure:

```swift
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

    window.title = AppIdentity.historyWindowTitle
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.toolbarStyle = .unified
    window.contentMinSize = Self.minimumSize
    window.identifier = NSUserInterfaceItemIdentifier("history-stats")
    window.contentViewController = NSHostingController(
      rootView: HistoryStatsRootView(appModel: appModel, selection: selection)
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
```

- [ ] **Step 4: Route app presentation through the controller**

In `AppDelegate.swift`, replace `private weak var historyWindow: NSWindow?` with:

```swift
private lazy var historyStatsWindowController = HistoryStatsWindowController(appModel: appModel)
```

Replace the inline body of `openHistoryWindow()` with:

```swift
private func openHistoryWindow() {
  popover?.performClose(nil)
  historyStatsWindowController.show()
}
```

Remove the `window === historyWindow` branch from `handleWindowWillClose(_:)`; retain its deferred `restoreAccessoryPolicyIfNeeded()` call because it also covers updater windows.

- [ ] **Step 5: Replace the custom content header with a native toolbar**

Make `HistoryStatsRootView.body` render only `content`. Create a local bindable projection before attaching the toolbar:

```swift
@Bindable var selection = selection

content
.toolbar {
  ToolbarItem(placement: .principal) {
    Picker("View", selection: $selection.destination) {
      ForEach(HistoryStatsTab.allCases) { tab in
        Label(tab.title, systemImage: tab.symbol).tag(tab)
      }
    }
    .pickerStyle(.segmented)
    .frame(width: 210)
  }

  if selection.destination == .stats {
    ToolbarItem(placement: .primaryAction) {
      Picker("Time Range", selection: $historyStatsWindowRaw) {
        Text("Today").tag(HistoryWindow.today.rawValue)
        Text("7 Days").tag(HistoryWindow.last7Days.rawValue)
        Text("30 Days").tag(HistoryWindow.last30Days.rawValue)
        Text("90 Days").tag(HistoryWindow.last90Days.rawValue)
        Text("All Time").tag(HistoryWindow.lifetime.rawValue)
      }
      .pickerStyle(.menu)
      .frame(width: 150)
    }
  }
}
```

Keep the existing `@AppStorage("historyStatsWindow")` key so current users retain their time-range selection. Remove `tabBar`, `tabButton`, the content divider, and the old 900 by 640 root minimum; the AppKit window now owns size constraints.

- [ ] **Step 6: Run focused and full tests**

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: the History and Stats UI suite passes.

Run: `rtk swift test`

Expected: all existing tests pass.

- [ ] **Step 7: Commit the native shell**

```bash
git add Sources/ILoveMusic/App/AppDelegate.swift Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift Tests/ILoveMusicTests/HistoryStatsUITests.swift
git commit -m "feat(stats): add native history workspace shell"
```

## Task 3: Establish the overview-first responsive page

**Files:**
- Create: `Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift`
- Modify: `Sources/ILoveMusic/UI/History/StatsView.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/StatsCard.swift`
- Delete: `Sources/ILoveMusic/UI/History/Charts/StatCardsRow.swift`
- Test: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`

- [ ] **Step 1: Add focused tests for page-level empty-state decisions**

Add a presentation helper inside `StatsLayout.swift`:

```swift
static func showsPageEmptyState(eventCountInWindow: Int) -> Bool {
  eventCountInWindow == 0
}
```

First add this failing test:

```swift
@Test
func emptyStateDependsOnTheSelectedWindow() {
  #expect(StatsLayout.showsPageEmptyState(eventCountInWindow: 0))
  #expect(!StatsLayout.showsPageEmptyState(eventCountInWindow: 1))
}
```

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: compilation fails until the helper is added, then passes.

- [ ] **Step 2: Replace the four large cards with one summary strip**

Create `StatsSummaryStrip.swift`. Use `ViewThatFits(in: .horizontal)` to try four, two, and one metric columns. The four metrics are exactly:

```swift
private var metrics: [(title: String, value: String, symbol: String, accent: Color)] {
  [
    ("Selected Period", formatShortListeningDuration(snapshot.totalListenedSecondsInWindow), "clock", .accentColor),
    ("Today", formatShortListeningDuration(snapshot.totalListenedSecondsToday), "sun.max", .secondary),
    ("Streak", "\(snapshot.dailyStreak) days", "flame.fill", snapshot.dailyStreak >= 3 ? .orange : .secondary),
    ("Average Session", formatShortListeningDuration(snapshot.averageSessionSeconds), "timer", .secondary),
  ]
}
```

Each metric cell uses a 10-point uppercase secondary label, a 20-point semibold monospaced value, and a small semantic symbol. Separate adjacent cells with `Divider()` inside one `StatsSection` surface. When `eventCountInWindow == 0`, values use an em dash instead of a zero duration.

- [ ] **Step 3: Turn `StatsCard` into a restrained section component**

Rename the type to `StatsSection` in `StatsCard.swift` and use this public interface:

```swift
struct StatsSection<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.headline)
        if let subtitle {
          Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
      }
      content()
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding(16)
    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
    }
  }
}
```

Remove all fixed minimum heights. Rename `StatsEmptyState` to `StatsSectionEmptyState` so the page-level empty state added next remains distinct.

- [ ] **Step 4: Reorder `StatsView` around the primary trend**

Use a top-level `GeometryReader` only to select the responsive layout, then a centered `ScrollView`:

```swift
GeometryReader { proxy in
  let contentWidth = min(proxy.size.width - 48, StatsLayout.maximumContentWidth)
  ScrollView {
    VStack(alignment: .leading, spacing: 18) {
      if StatsLayout.showsPageEmptyState(eventCountInWindow: snapshot.eventCountInWindow) {
        StatsPageEmptyState(window: window)
      } else {
        StatsSummaryStrip(snapshot: snapshot)
        primaryTrend(snapshot: snapshot)
        supportingBreakdowns(snapshot: snapshot, width: contentWidth)
        listeningPatterns(snapshot: snapshot, width: contentWidth)
        rankings(snapshot: snapshot, width: contentWidth)
      }
    }
    .frame(width: max(0, contentWidth), alignment: .topLeading)
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity)
  }
}
```

Implement each named builder in the same file. Use `LazyVGrid` with one or two flexible columns according to `StatsLayout.supportingColumns(for:)`. Put Listening Trend before every supporting chart. Prefix rankings with `StatsLayout.rankingLimit(for:)`.

The page-level empty state uses `chart.bar.xaxis`, the title `No listening in this period`, and the subtitle `Choose a broader time range or start listening to see your activity here.` Do not show multiple section empty states when the selected period has no events.

- [ ] **Step 5: Remove the old summary component and update references**

Delete `StatCardsRow.swift`, replace every `StatsCard` reference with `StatsSection`, and replace nested `StatsEmptyState` references with `StatsSectionEmptyState`.

- [ ] **Step 6: Run tests and compile the app**

Run: `rtk swift test`

Expected: all tests pass and the new responsive page compiles.

- [ ] **Step 7: Commit the hierarchy**

```bash
git add Sources/ILoveMusic/UI/History/StatsLayout.swift Sources/ILoveMusic/UI/History/StatsView.swift Sources/ILoveMusic/UI/History/Charts/StatsCard.swift Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift Tests/ILoveMusicTests/HistoryStatsUITests.swift
git add -u Sources/ILoveMusic/UI/History/Charts/StatCardsRow.swift
git commit -m "feat(stats): build responsive overview hierarchy"
```

## Task 4: Add shared chart selection and an interactive primary trend

**Files:**
- Create: `Sources/ILoveMusic/UI/History/Charts/ChartSelection.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/ListeningTrendChart.swift`
- Test: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`

- [ ] **Step 1: Write failing geometry tests**

Add:

```swift
@Test
func chartSelectionClampsToVisibleSlots() {
  #expect(ChartSelection.index(at: -1, plotWidth: 240, count: 24) == nil)
  #expect(ChartSelection.index(at: 0, plotWidth: 240, count: 24) == 0)
  #expect(ChartSelection.index(at: 239, plotWidth: 240, count: 24) == 23)
  #expect(ChartSelection.index(at: 240, plotWidth: 240, count: 24) == nil)
  #expect(ChartSelection.index(at: 20, plotWidth: 0, count: 24) == nil)
}

@Test
func edgeLabelsUseReadableAlignment() {
  #expect(ChartSelection.edge(for: 0, count: 7) == .leading)
  #expect(ChartSelection.edge(for: 3, count: 7) == .center)
  #expect(ChartSelection.edge(for: 6, count: 7) == .trailing)
}
```

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: compilation fails because `ChartSelection` does not exist.

- [ ] **Step 2: Implement the pure helper**

Create `ChartSelection.swift`:

```swift
import Foundation

enum ChartLabelEdge: Equatable {
  case leading
  case center
  case trailing
}

enum ChartSelection {
  static func index(at x: CGFloat, plotWidth: CGFloat, count: Int) -> Int? {
    guard count > 0, plotWidth > 0, x >= 0, x < plotWidth else { return nil }
    return min(count - 1, Int((x / plotWidth) * CGFloat(count)))
  }

  static func edge(for index: Int, count: Int) -> ChartLabelEdge {
    if index == 0 { return .leading }
    if index == count - 1 { return .trailing }
    return .center
  }
}
```

- [ ] **Step 3: Add trend hover selection**

In `ListeningTrendChart`, add `@State private var selectedIndex: Int?`. Normalize hourly and daily inputs into a small private `TrendPoint` array with `label`, `axisValue`, and `listenedSeconds`. Render one chart path for both modes.

Attach a `chartOverlay` that converts the pointer location into the plot coordinate system and calls `ChartSelection.index(at:plotWidth:count:)`. Map `ChartLabelEdge` to the corresponding SwiftUI annotation alignment. Add a `RuleMark` and `PointMark` when a point is selected. The annotation must render:

```swift
VStack(alignment: .leading, spacing: 2) {
  Text(point.label).font(.caption.weight(.semibold))
  Text(formatShortListeningDuration(point.listenedSeconds))
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
}
.padding(8)
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
```

Keep the chart at 180 points high. Use an explicit y-domain from zero through `max(1, maximumSeconds * 1.12)`, compact duration labels on the y-axis, and leading/trailing alignment for edge labels. Clear selection on pointer exit.

- [ ] **Step 4: Add chart accessibility**

Give the chart `.accessibilityLabel("Listening trend")` and a summary value using the selected period total. Add an accessibility child for every nonzero point with the point label and formatted duration. Do not expose decorative area and line marks separately.

- [ ] **Step 5: Run focused and full tests**

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: selection geometry tests pass.

Run: `rtk swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit the interactive trend**

```bash
git add Sources/ILoveMusic/UI/History/Charts/ChartSelection.swift Sources/ILoveMusic/UI/History/Charts/ListeningTrendChart.swift Tests/ILoveMusicTests/HistoryStatsUITests.swift
git commit -m "feat(stats): add interactive listening trend"
```

## Task 5: Make supporting charts responsive and inspectable

**Files:**
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopChannelsChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/GenreDonutChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/HourOfDayChart.swift`

- [ ] **Step 1: Add pointer selection to Top Channels**

Add `@State private var selectedID: ChannelTotal.ID?`. Use one transparent chart overlay so drawing and pointer selection operate on the same displayed channel array:

```swift
.chartOverlay { proxy in
  GeometryReader { geometry in
    Rectangle().fill(.clear).contentShape(Rectangle())
      .onContinuousHover { phase in
        updateChannelSelection(phase, proxy: proxy, geometry: geometry)
      }
  }
}
```

`updateChannelSelection` must resolve the nearest bar from the pointer's plot-frame y coordinate, clear on exit, and use the same displayed channel array as the chart. Dim unselected bars to 45 percent opacity. Show station name, formatted duration, and play count in the tooltip. Add an overall `Top channels` accessibility label and one child per bar.

- [ ] **Step 2: Make the genre module adapt without fixed dimensions**

Wrap the donut and legend in `ViewThatFits(in: .horizontal)`: first try an `HStack`, then a `VStack`. Use a donut size of 132 points in the horizontal layout and 118 points in the vertical layout. Limit the visible legend to the existing `shares` input, align percentages in a monospaced trailing column, and give every sector an accessibility label containing category, percentage, and duration.

- [ ] **Step 3: Add pointer selection to Listening by Hour**

Use `ChartSelection.index(at:plotWidth:count:)` for the 24 fixed bars. A selected hour uses full accent opacity; other nonzero bars use 55 percent; zero bars use 12 percent. Render a tooltip such as `18:00–19:00` and the formatted duration. Use an explicit zero-based domain and axis marks at 0, 6, 12, 18, and 23. Keep the chart 175 points high and add an accessibility child for each nonzero hour.

- [ ] **Step 4: Remove section-local empty overlays that can compete with the page empty state**

Supporting components may keep a small `StatsSectionEmptyState` for structurally unavailable data such as missing genre metadata, but `StatsView` must prevent the complete empty dashboard from rendering. Ensure every local empty state has a fixed minimum content height of 130 points instead of inheriting an unbounded spacer layout.

- [ ] **Step 5: Compile and run the suite**

Run: `rtk swift test`

Expected: all tests pass and every supporting chart compiles with Swift Charts.

- [ ] **Step 6: Commit supporting charts**

```bash
git add Sources/ILoveMusic/UI/History/Charts/TopChannelsChart.swift Sources/ILoveMusic/UI/History/Charts/GenreDonutChart.swift Sources/ILoveMusic/UI/History/Charts/HourOfDayChart.swift Sources/ILoveMusic/UI/History/Charts/StatsCard.swift
git commit -m "feat(stats): refine supporting charts"
```

## Task 6: Rebuild the heatmap for pointer, keyboard, and VoiceOver use

**Files:**
- Modify: `Sources/ILoveMusic/UI/History/Charts/WeekdayHourHeatmap.swift`
- Test: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`

- [ ] **Step 1: Add failing heatmap coordinate tests**

Add pure helpers to the existing heatmap type and first write:

```swift
@Test
func heatmapCoordinateNavigationStaysInBounds() {
  #expect(HeatmapSelection(row: 0, hour: 0).moving(rowDelta: -1, hourDelta: 0) == HeatmapSelection(row: 0, hour: 0))
  #expect(HeatmapSelection(row: 6, hour: 23).moving(rowDelta: 1, hourDelta: 1) == HeatmapSelection(row: 6, hour: 23))
  #expect(HeatmapSelection(row: 2, hour: 8).moving(rowDelta: 1, hourDelta: -1) == HeatmapSelection(row: 3, hour: 7))
}
```

Run: `rtk swift test --filter HistoryStatsUITests`

Expected: compilation fails because `HeatmapSelection` does not exist.

- [ ] **Step 2: Add bounded selection state**

Define beside the heatmap:

```swift
struct HeatmapSelection: Hashable {
  let row: Int
  let hour: Int

  func moving(rowDelta: Int, hourDelta: Int) -> Self {
    Self(
      row: min(6, max(0, row + rowDelta)),
      hour: min(23, max(0, hour + hourDelta))
    )
  }
}
```

- [ ] **Step 3: Render from shared width-derived geometry**

Keep seven rows and 24 columns. Derive cell pitch from the actual plot width with:

```swift
let pitch = max(8, availableWidth / 24)
let cellSize = max(5, min(15, pitch - 3))
```

Use one geometry calculation for drawing, pointer hit testing, selection outline, and tooltip placement. Remove the current hardcoded `maxCellSize` path that can leave unused horizontal space. Add a four-step `Less` to `More` intensity legend below the grid.

- [ ] **Step 4: Add pointer and keyboard interaction**

Track one `HeatmapSelection?`. Continuous hover selects the cell under the pointer; clicking keeps the selection. Make the heatmap focusable and use `onKeyPress` for the four arrow keys, calling `moving(rowDelta:hourDelta:)`. Draw a two-point accent outline around the selected cell and show weekday, hour range, and formatted duration in a material tooltip.

- [ ] **Step 5: Add accessibility children**

Use `.accessibilityElement(children: .contain)` on the grid and create one child per nonzero cell. Labels follow `Monday, 18:00 to 19:00`; values use `formatShortListeningDuration`. Add adjustable actions that move selection forward or backward through the 168 cells.

- [ ] **Step 6: Run tests and commit**

Run: `rtk swift test`

Expected: the coordinate suite and all existing tests pass.

```bash
git add Sources/ILoveMusic/UI/History/Charts/WeekdayHourHeatmap.swift Tests/ILoveMusicTests/HistoryStatsUITests.swift
git commit -m "feat(stats): make listening heatmap interactive"
```

## Task 7: Calm the rankings and History list

**Files:**
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopArtistsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopSongsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryListView.swift`

- [ ] **Step 1: Compact both ranking components**

Use 8-point row spacing, 12-point primary text, 10-point secondary monospaced values, and separators between rows instead of a large gap after every item. Keep the artist proportional indicator at four points high. Keep song artwork at 28 points with a 7-point corner radius. Preserve the inputs supplied by `StatsView`; the responsive row limit belongs in the parent.

- [ ] **Step 2: Replace the hand-built search field with native controls**

Change the History filter bar to:

```swift
HStack(spacing: 10) {
  TextField("Search songs, artists, or channels", text: $query)
    .textFieldStyle(.roundedBorder)
    .frame(maxWidth: 320)

  Picker("Channel", selection: $stationFilter) {
    Text("All Channels").tag(StationFilter.all)
    ForEach(stationsForMenu, id: \.stationID) { station in
      Text(station.stationName).tag(StationFilter.station(station.stationID))
    }
  }
  .pickerStyle(.menu)
  .frame(maxWidth: 220)

  Spacer()
  Text("\(matchCount.formatted(.number)) songs")
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
}
.padding(.horizontal, 16)
.padding(.vertical, 10)
```

- [ ] **Step 3: Turn history cards into native compact rows**

Remove `isHovering`, the gradient background, the custom border, and `onHover`. Use 38-point artwork, six points of vertical row padding, and a plain list row background. Keep the existing title fallback, station tint, start time, duration, copy action, and station-filter action. Set `.listRowSeparator(.visible)` and use standard list selection/hover behavior rather than painting a second card system inside `List`.

- [ ] **Step 4: Make History copy consistently English**

Use these exact replacements:

- `Heute` to `Today`
- `Gestern` to `Yesterday`
- `Alle Channels` to `All Channels`
- `Unbekannter Track` to `Unknown Track`
- `Kopieren` to `Copy`
- `Nach diesem Channel filtern` to `Filter by This Channel`
- duration fallback `0 Sek.` to `0 sec`

Keep the existing English empty-state copy and `Open Settings…` action. Do not add a localization framework in this task.

- [ ] **Step 5: Run the full suite**

Run: `rtk swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit rankings and History**

```bash
git add Sources/ILoveMusic/UI/History/Charts/TopArtistsCard.swift Sources/ILoveMusic/UI/History/Charts/TopSongsCard.swift Sources/ILoveMusic/UI/History/HistoryListView.swift
git commit -m "feat(history): simplify rankings and listening list"
```

## Task 8: Perform runtime visual QA and update documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/screenshots/stats.png`

- [ ] **Step 1: Run the complete automated checks**

Run: `rtk swift test`

Expected: all tests pass.

Run: `./Scripts/build-app.sh`

Expected: `.build/ILoveMusic.app` is produced and the script's signature verification succeeds.

Run: `codesign --verify --deep --strict .build/ILoveMusic.app`

Expected: exit status 0 with no verification error.

- [ ] **Step 2: Open the built app without replacing the installed app**

Run: `open .build/ILoveMusic.app`

Open History and Stats from the menu-bar footer, then close it and open it from the right-click menu. Confirm both routes reuse one window and bring it forward.

- [ ] **Step 3: Verify window and responsive behavior**

Check these sizes manually:

- default 1040 by 760;
- minimum 760 by 560;
- approximately 850 by 900;
- at least 1400 points wide.

At each size confirm the trend remains full width, support sections switch between two and one columns without clipped legends, rankings show 8 or 5 rows as designed, the heatmap remains legible, and no horizontal scrolling appears. Move and resize the window, close it, reopen it, and confirm macOS restores the saved frame instead of recentering it.

- [ ] **Step 4: Verify data states and interaction**

Check Today, 7 Days, 30 Days, 90 Days, and All Time. Confirm a period with no events shows one page-level empty state. For populated periods, hover the trend, channel bars, hourly bars, and heatmap; verify highlighted values match visible data. Focus the heatmap and move with all four arrow keys. Use Accessibility Inspector or VoiceOver to confirm chart summaries and individual values are announced.

- [ ] **Step 5: Verify native appearance variants**

Check light and dark appearances, Increase Contrast, and Reduce Transparency. Confirm semantic borders remain visible, selected data remains distinguishable without relying only on opacity, toolbar controls remain readable, and no decorative gradient remains in History rows.

- [ ] **Step 6: Capture the final screenshot**

Capture the populated Stats destination at its default size in dark appearance. Crop only the window shadow and surrounding desktop; do not crop window content. Replace `docs/screenshots/stats.png` with the verified capture.

- [ ] **Step 7: Update the README description**

Replace the sentence below the Stats screenshot with:

```markdown
Das native, frei skalierbare Fenster bündelt Verlauf und Statistik in einer gemeinsamen Toolbar. Die Übersicht priorisiert Hörzeit und Trend; adaptive Verteilungen, Heatmap und Rankings liefern Details mit Hover-, Tastatur- und VoiceOver-Unterstützung.
```

- [ ] **Step 8: Review the exact final scope and commit**

Run: `git status --short`

Expected: only the intended History/Stats source files, focused test, README, and screenshot are changed.

Run: `git diff --check`

Expected: no whitespace errors.

```bash
git add README.md docs/screenshots/stats.png Sources/ILoveMusic/UI/History Tests/ILoveMusicTests/HistoryStatsUITests.swift Sources/ILoveMusic/App/AppDelegate.swift
git commit -m "docs: refresh native stats workspace"
```

- [ ] **Step 9: Confirm the handoff is clean**

Run: `git status --short`

Expected: no output.

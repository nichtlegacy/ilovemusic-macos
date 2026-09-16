# German and English localization implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize every app-owned ILoveMusic interface string into English and German, with a persisted `System Default / Deutsch / English` selector that takes effect after restart.

**Architecture:** A Codable `AppLanguage` preference is captured as an immutable active language when `AppModel` starts. SwiftUI roots receive its locale, AppKit resolves the same `LocalizedStringResource` values explicitly, and one SwiftPM `Localizable.xcstrings` catalog owns English source text plus German translations. Technical logs, Discord activity payloads, and server-supplied content stay unchanged.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation localization APIs, String Catalogs, Swift Package Manager, Swift Testing

---

## Current baseline

- `Package.swift` already declares `defaultLocalization: "en"` and processes `Sources/ILoveMusic/Resources`.
- The release build copies the complete `ILoveMusic_ILoveMusic.bundle`; no separate `.lproj` copy step is needed.
- Settings currently has seven panes: General, Playback, Discord, Stream Deck, Data, Advanced, and About.
- Settings and History use dedicated AppKit window controllers.
- `swift test` passed 96 tests before this plan was written.
- History and Stats has an uncommitted redesign in the shared working tree. Preserve it. Re-read those files immediately before Tasks 7 and 8.

## File map

**Create**

- `Sources/ILoveMusic/Support/AppLocalization.swift`: locale selection and shared resource resolution.
- `Sources/ILoveMusic/Resources/Localizable.xcstrings`: English source strings, German translations, comments, and plural variants.
- `Tests/ILoveMusicTests/LocalizationTests.swift`: language persistence, resolution, fallback, and restart behavior.
- `Tests/ILoveMusicTests/LocalizationCatalogTests.swift`: bundle and catalog integrity checks.

**Modify**

- `Sources/ILoveMusic/Domain/Models.swift`: `AppLanguage`, persisted preference, and localizable domain labels.
- `Sources/ILoveMusic/Domain/HotkeyBinding.swift`: localizable hotkey action names.
- `Sources/ILoveMusic/App/AppModel.swift`: immutable launch language, update method, and restart state.
- `Sources/ILoveMusic/App/AppModel+PreferenceBindings.swift`: Settings binding.
- `Sources/ILoveMusic/App/AppDelegate.swift`: locale injection and localized AppKit context menu.
- `Sources/ILoveMusic/Support/AppIdentity.swift`: localized History and Stats window title resource.
- `Sources/ILoveMusic/Support/DurationFormatting.swift`: locale-aware human-readable durations.
- `Sources/ILoveMusic/Support/Extensions.swift`: locale-aware date display helpers.
- `Scripts/build-app.sh`: language metadata in the generated app Info.plist.
- Menu-bar, Settings, History, and chart files listed in Tasks 5 through 7.
- Existing localization-adjacent tests listed in each task.

## Task 1: Persist the language and freeze it at launch

**Files:**

- Create: `Tests/ILoveMusicTests/LocalizationTests.swift`
- Modify: `Sources/ILoveMusic/Domain/Models.swift`
- Modify: `Sources/ILoveMusic/App/AppModel.swift`
- Modify: `Sources/ILoveMusic/App/AppModel+PreferenceBindings.swift`
- Modify: `Tests/ILoveMusicTests/AppStateStoreTests.swift`
- Modify: `Tests/ILoveMusicTests/SettingsBindingTests.swift`

- [ ] **Step 1: Add failing model and persistence tests**

Create focused tests for the three stable raw values, forward-compatible decoding, and an absent preference:

```swift
import Foundation
import Testing
@testable import ILoveMusic

@Suite("App language")
struct LocalizationTests {
  @Test
  func appLanguageRawValuesAreStable() {
    #expect(AppLanguage.system.rawValue == "system")
    #expect(AppLanguage.german.rawValue == "de")
    #expect(AppLanguage.english.rawValue == "en")
  }

  @Test
  func unknownLanguageFallsBackWithoutThrowing() throws {
    let decoded = try JSONDecoder().decode(AppLanguage.self, from: Data("\"future-language\"".utf8))
    #expect(decoded == .system)
  }

  @Test
  func missingPreferenceUsesSystemLanguage() {
    #expect(UserPreferences.default.effectiveAppLanguage == .system)
  }
}
```

Extend the existing state round-trip fixture so it sets `appLanguage` to each case and expects the same effective value after loading. Add a legacy JSON fixture without `appLanguage` and expect `.system` while checking an unrelated preference survives.

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
swift test --filter 'App language|AppStateStore|Settings preference bindings'
```

Expected: compilation fails because `AppLanguage`, `appLanguage`, and `effectiveAppLanguage` do not exist.

- [ ] **Step 3: Add the forward-compatible language model**

Add this model near `UserPreferences` in `Models.swift`:

```swift
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
  case system
  case german = "de"
  case english = "en"

  var id: Self { self }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = Self(rawValue: rawValue) ?? .system
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
```

Add `var appLanguage: AppLanguage?` to `UserPreferences`, set it to `.system` in `.default`, and expose:

```swift
var effectiveAppLanguage: AppLanguage { appLanguage ?? .system }
```

Keep the property optional so synthesized decoding accepts state files written before localization.

- [ ] **Step 4: Capture the active language and add the Settings binding**

Add `private(set) var activeLanguage: AppLanguage` to `AppModel`. Initialize it from the same loaded snapshot used for `preferences`:

```swift
let persisted = self.stateStore.load()
preferences = persisted.preferences
activeLanguage = persisted.preferences.effectiveAppLanguage
```

Add:

```swift
var requiresLanguageRestart: Bool {
  preferences.effectiveAppLanguage != activeLanguage
}

func updateAppLanguage(_ value: AppLanguage) {
  preferences.appLanguage = value
  persist()
}
```

Add the bindable accessor:

```swift
var appLanguage: AppLanguage {
  get { preferences.effectiveAppLanguage }
  set { updateAppLanguage(newValue) }
}
```

- [ ] **Step 5: Make the tests pass**

Run:

```bash
swift test --filter 'App language|AppStateStore|Settings preference bindings'
```

Expected: all selected suites pass, including legacy state decoding and all three round trips.

- [ ] **Step 6: Commit the persistence slice**

```bash
git add Sources/ILoveMusic/Domain/Models.swift Sources/ILoveMusic/App/AppModel.swift Sources/ILoveMusic/App/AppModel+PreferenceBindings.swift Tests/ILoveMusicTests/LocalizationTests.swift Tests/ILoveMusicTests/AppStateStoreTests.swift Tests/ILoveMusicTests/SettingsBindingTests.swift
git commit -m "feat: persist app language preference"
```

## Task 2: Add the String Catalog and release metadata

**Files:**

- Create: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Create: `Tests/ILoveMusicTests/LocalizationCatalogTests.swift`
- Modify: `Tests/ILoveMusicTests/ResourcesAuditTests.swift`
- Modify: `Scripts/build-app.sh`

- [ ] **Step 1: Add failing bundle and release-script assertions**

Add these resource assertions:

```swift
#expect(Bundle.module.localizations.contains("en"))
#expect(Bundle.module.localizations.contains("de"))
#expect(Bundle.module.developmentLocalization == "en")
```

Add a catalog test that loads `Sources/ILoveMusic/Resources/Localizable.xcstrings` from the repository root, checks `sourceLanguage == "en"`, and requires a German localization for each shipping key. The recursive German check must accept both a direct `stringUnit` and plural `variations.plural` leaves.

- [ ] **Step 2: Run the resource tests and confirm they fail**

```bash
swift test --filter 'bundledResources|Localization catalog'
```

Expected: the bundle does not yet report `de`, and the catalog file is missing.

- [ ] **Step 3: Create the initial catalog**

Create a valid Xcode 16+ catalog with this initial shape:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "System Default" : {
      "comment" : "Language picker option that follows the macOS app language.",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Systemstandard"
          }
        }
      }
    }
  },
  "version" : "1.1"
}
```

Later tasks add their complete key sets to this same catalog.

- [ ] **Step 4: Declare the app languages in the generated Info.plist**

Add these keys in `Scripts/build-app.sh`:

```xml
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>de</string>
  </array>
```

Do not add a second resource-copy command. The existing `cp -R "${BUILD_DIR}/${RESOURCE_BUNDLE}"` already copies compiled localization directories.

- [ ] **Step 5: Run the focused tests**

```bash
swift test --filter 'bundledResources|Localization catalog'
```

Expected: the initial catalog compiles into the SwiftPM resource bundle and all focused tests pass.

- [ ] **Step 6: Commit the catalog foundation**

```bash
git add Sources/ILoveMusic/Resources/Localizable.xcstrings Scripts/build-app.sh Tests/ILoveMusicTests/LocalizationCatalogTests.swift Tests/ILoveMusicTests/ResourcesAuditTests.swift
git commit -m "feat: add localization catalog foundation"
```

## Task 3: Apply one locale to every UI root and add the restart picker

**Files:**

- Create: `Sources/ILoveMusic/Support/AppLocalization.swift`
- Modify: `Sources/ILoveMusic/App/AppDelegate.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/GeneralPane.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Modify: `Tests/ILoveMusicTests/LocalizationTests.swift`
- Modify: `Tests/ILoveMusicTests/SettingsNavigationTests.swift`

- [ ] **Step 1: Add failing locale-resolution and restart tests**

Test the resolution contract:

```swift
@Test(arguments: [
  (AppLanguage.german, "de"),
  (AppLanguage.english, "en"),
])
func explicitLanguageResolvesLocale(language: AppLanguage, identifier: String) {
  #expect(language.locale?.language.languageCode?.identifier == identifier)
}

@Test
func changingSavedLanguageRequiresRestart() throws {
  let fixture = try makeLocalizationTestModel(language: .english)
  #expect(fixture.model.activeLanguage == .english)
  #expect(!fixture.model.requiresLanguageRestart)
  fixture.model.appLanguage = .german
  #expect(fixture.model.activeLanguage == .english)
  #expect(fixture.model.requiresLanguageRestart)
  fixture.model.appLanguage = .english
  #expect(!fixture.model.requiresLanguageRestart)
}
```

- [ ] **Step 2: Implement locale and resource resolution**

Create `AppLocalization.swift`:

```swift
import Foundation

extension AppLanguage {
  var locale: Locale? {
    switch self {
    case .system: nil
    case .german: Locale(identifier: "de")
    case .english: Locale(identifier: "en")
    }
  }

  var resolvedLocale: Locale { locale ?? .current }
}

enum AppLocalization {
  static func string(
    _ resource: LocalizedStringResource,
    language: AppLanguage
  ) -> String {
    var resource = resource
    resource.locale = language.resolvedLocale
    return String(localized: resource)
  }
}

extension LocalizedStringResource {
  func resolved(in locale: Locale) -> Self {
    var resource = self
    resource.locale = locale
    return resource
  }
}
```

Every `LocalizedStringResource` created for this target must pass `bundle: #bundle` so lookup happens in the SwiftPM resource bundle.

- [ ] **Step 3: Inject the active locale into all three SwiftUI roots**

Apply `.environment(\.locale, appModel.activeLanguage.resolvedLocale)` to:

```swift
MenuBarPanelView(appModel: appModel, playbackController: playbackController)
SettingsView(appModel: appModel, selection: selection, onSelectionChange: ...)
HistoryStatsRootView(appModel: appModel, selection: selection)
```

Do not read the mutable saved preference here. All three roots use `activeLanguage` until the process exits.

- [ ] **Step 4: Add the three-option picker and persistent restart notice**

Add a language row to `GeneralPane`'s System section:

```swift
Picker("Language", selection: $appModel.appLanguage) {
  Text("System Default", bundle: #bundle).tag(AppLanguage.system)
  Text("Deutsch", bundle: #bundle).tag(AppLanguage.german)
  Text("English", bundle: #bundle).tag(AppLanguage.english)
}
.pickerStyle(.menu)
```

When `appModel.requiresLanguageRestart` is true, show an inline notice below the picker. Resolve the selected language name using the current session locale, not the newly selected locale:

```swift
VStack(alignment: .leading, spacing: 8) {
  Label("The language changes after you restart ILoveMusic.", systemImage: "arrow.clockwise")
    .font(.footnote)
    .foregroundStyle(.secondary)
  HStack {
    Spacer()
    Button("Quit ILoveMusic") {
      NSApplication.shared.terminate(nil)
    }
  }
}
```

The normal `applicationWillTerminate` path flushes queued preferences. Do not add an alternate exit path.

- [ ] **Step 5: Add English and German picker strings**

Add translations for `Language`, `System Default`, the restart sentence, and `Quit ILoveMusic`. Keep the language names self-identifying: `Deutsch` and `English` in both catalog languages.

- [ ] **Step 6: Run focused tests and compile all UI roots**

```bash
swift test --filter 'App language|Settings navigation'
swift build
```

Expected: all tests pass and the three hosting roots compile with the locale environment.

- [ ] **Step 7: Commit locale routing and the picker**

```bash
git add Sources/ILoveMusic/Support/AppLocalization.swift Sources/ILoveMusic/App/AppDelegate.swift Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift Sources/ILoveMusic/UI/Settings/Panes/GeneralPane.swift Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/LocalizationTests.swift Tests/ILoveMusicTests/SettingsNavigationTests.swift
git commit -m "feat: add restart-based language selector"
```

## Task 4: Make shared labels localizable without touching runtime data

**Files:**

- Modify: `Sources/ILoveMusic/Domain/Models.swift`
- Modify: `Sources/ILoveMusic/Domain/HotkeyBinding.swift`
- Modify: `Sources/ILoveMusic/Support/AppIdentity.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsShared.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/StatsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Modify: `Tests/ILoveMusicTests/SettingsNavigationTests.swift`

- [ ] **Step 1: Add failing tests for shared display resources**

Assert representative German values through `AppLocalization.string`:

```swift
#expect(AppLocalization.string(SettingsTab.general.titleResource, language: .german) == "Allgemein")
#expect(AppLocalization.string(StationSortPreference.alphabetical.titleResource, language: .german) == "Alphabetisch")
#expect(AppLocalization.string(PlaybackPhase.buffering.titleResource, language: .german) == "Wird geladen")
#expect(AppLocalization.string(HotkeyID.nextStation.titleResource, language: .german) == "Nächster Sender")
```

- [ ] **Step 2: Replace app-owned `String` display properties with resources**

Rename display properties to make their type clear:

```swift
var titleResource: LocalizedStringResource {
  switch self {
  case .general:
    LocalizedStringResource("General", bundle: #bundle, comment: "Settings sidebar item")
  case .playback:
    LocalizedStringResource("Playback", bundle: #bundle, comment: "Settings sidebar item")
  case .discord:
    LocalizedStringResource("Discord", bundle: #bundle, comment: "Settings sidebar item")
  case .streamDeck:
    LocalizedStringResource("Stream Deck", bundle: #bundle, comment: "Settings sidebar item")
  case .data:
    LocalizedStringResource("Data", bundle: #bundle, comment: "Settings sidebar item")
  case .advanced:
    LocalizedStringResource("Advanced", bundle: #bundle, comment: "Settings sidebar item")
  case .about:
    LocalizedStringResource("About", bundle: #bundle, comment: "Settings sidebar item")
  }
}
```

Apply this pattern to:

- `SettingsTab`
- `StationCategory`
- `StationSortPreference`
- `CatalogSource`
- `PlaybackPhase`
- `HotkeyID`
- app-owned window titles in `AppIdentity`

Keep `StreamFormatPreference` values `AAC` and `MP3` verbatim. Keep `DiscordRichPresenceManager.State.label` as English `String` because Discord diagnostics and activity remain English.

- [ ] **Step 3: Change shared UI components to accept resources**

Change app-owned label properties in `SettingsRowLabel`, `SettingsToggle`, `StatsCard`, `StatsEmptyState`, and `StatsSummaryStrip` from `String` to `LocalizedStringResource`. Resolve them with the view's `@Environment(\.locale)` by copying the resource and assigning that locale before `Text(resource)`.

Use this rendering shape in each shared component:

```swift
@Environment(\.locale) private var locale

var body: some View {
  Text(title.resolved(in: locale))
}
```

Keep parameters that carry station names, artists, songs, stored log messages, or preformatted numeric values as `String` and render them verbatim.

- [ ] **Step 4: Unify Settings sidebar and window titles**

Use `SettingsTab.titleResource` in `SettingsSidebar`. In `SettingsWindowController`, resolve the same resource with `appModel.activeLanguage` for both the initial `window.title` and `onSelectionChange`. This removes the current dynamic `Text(tab.title)` localization hole and prevents sidebar/window-title drift.

- [ ] **Step 5: Add the complete shared-label translation set**

Use these German terms consistently:

| English | German |
| --- | --- |
| General | Allgemein |
| Playback | Wiedergabe |
| Data | Daten |
| Advanced | Erweitert |
| About | Über |
| History & Stats | Verlauf & Statistiken |
| Popularity | Beliebtheit |
| Alphabetical | Alphabetisch |
| Ready | Bereit |
| Buffering | Wird geladen |
| Playing | Wiedergabe |
| Paused | Pausiert |
| Reconnecting | Verbindung wird wiederhergestellt |
| Failed | Fehlgeschlagen |

Brand names `Discord` and `Stream Deck` do not change.

- [ ] **Step 6: Run the focused tests**

```bash
swift test --filter 'App language|Settings navigation'
swift build
```

Expected: resources resolve to the asserted German values and all shared components compile.

- [ ] **Step 7: Commit shared localization types**

```bash
git add Sources/ILoveMusic/Domain/Models.swift Sources/ILoveMusic/Domain/HotkeyBinding.swift Sources/ILoveMusic/Support/AppIdentity.swift Sources/ILoveMusic/UI/Settings/SettingsView.swift Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift Sources/ILoveMusic/UI/Settings/SettingsShared.swift Sources/ILoveMusic/UI/History/Charts/StatsCard.swift Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/SettingsNavigationTests.swift
git commit -m "refactor: pass localizable display resources"
```

## Task 5: Localize the menu-bar experience and AppKit menu

**Files:**

- Modify: `Sources/ILoveMusic/App/AppDelegate.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/FooterBar.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/HeroSection.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/MenuBarPanelView.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/StationDetailPopover.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/StationRowView.swift`
- Modify: `Sources/ILoveMusic/UI/MenuBar/StationsListSection.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Modify: `Tests/ILoveMusicTests/MenuBarAuditTests.swift`

- [ ] **Step 1: Add focused AppKit menu localization tests**

Extract context-menu title creation into a small internal method that returns menu items for a supplied language and state. Test at least:

```swift
#expect(germanTitles.contains("Wiedergabe"))
#expect(germanTitles.contains("Nächster Sender"))
#expect(germanTitles.contains("Zufälliger Sender"))
#expect(germanTitles.contains("Einstellungen…"))
#expect(germanTitles.contains("ILoveMusic beenden"))
#expect(englishTitles.contains("Check for Updates…"))
```

Also assert a station name and song line pass through unchanged.

- [ ] **Step 2: Localize every `NSMenuItem` title**

Create resources inline so Xcode can extract them, then resolve with `appModel.activeLanguage`:

```swift
let title = AppLocalization.string(
  LocalizedStringResource(
    "Next Station",
    bundle: #bundle,
    comment: "Menu item that starts the next radio station."
  ),
  language: appModel.activeLanguage
)
```

Apply the same pattern to no-station, no-song, play/pause, random, show/hide panel, refresh, History and Stats, Settings, update, and quit. Do not localize `station.displayName`, artist, or song title.

- [ ] **Step 3: Localize SwiftUI menu-bar controls**

Cover all app-owned labels, help text, accessibility labels, status text, empty states, favorite actions, AirPlay help, listener counts, and station-list headings across the six menu-bar view files. Use `Text(verbatim:)` for server content where overload selection could otherwise treat a dynamic string as a localization key.

- [ ] **Step 4: Add listener plurals**

Use one interpolated catalog key for counts instead of manual suffix logic:

```swift
Text(
  LocalizedStringResource(
    "\(count) listeners",
    bundle: #bundle,
    comment: "Number of people currently listening to a station."
  )
)
```

Configure English `one/other` and German `one/other` variants. Keep Discord's separate listener suffix logic unchanged because its payload stays English.

- [ ] **Step 5: Run menu tests and the full build**

```bash
swift test --filter 'MenuBar|App language'
swift build
```

Expected: tests pass, AppKit titles resolve in both languages, and dynamic station/song values remain unchanged.

- [ ] **Step 6: Commit menu-bar localization**

```bash
git add Sources/ILoveMusic/App/AppDelegate.swift Sources/ILoveMusic/UI/MenuBar Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/MenuBarAuditTests.swift
git commit -m "feat: localize menu bar interface"
```

## Task 6: Localize the current seven-pane Settings UI

**Files:**

- Modify: `Sources/ILoveMusic/UI/Settings/Components/HotkeyRecorderRow.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Components/LogPanel.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/AboutPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/AdvancedPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/DataPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/DiscordPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/GeneralPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/PlaybackPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/StreamDeckPane.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsSidebar.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsView.swift`
- Modify: `Sources/ILoveMusic/UI/Settings/SettingsWindowController.swift`
- Modify: `Sources/ILoveMusic/Services/LaunchAtLoginManager.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Modify: `Tests/ILoveMusicTests/SettingsUIAuditTests.swift`

- [ ] **Step 1: Add tests for the intentional English boundaries**

Add assertions that localized Settings chrome changes while diagnostic payloads do not:

```swift
#expect(localizedAdvancedTitle == "Erweitert")
#expect(controlEntry.message == originalControlMessage)
#expect(discordEntry.message == originalDiscordMessage)
#expect(discordPresenceState == originalEnglishPresenceState)
```

Add a test for German hotkey conflict interpolation with two localized action names.

- [ ] **Step 2: Localize General, Playback, Data, and About**

Convert every section header, row title, subtitle, button, help string, accessibility label, confirmation title, confirmation message, and empty value. Make `Version \(version) (\(build))` a catalog interpolation. Preserve `ILoveMusic`, version numbers, URLs, hotkey glyphs, `AAC`, and `MP3` verbatim.

Convert Launch at Login's user-facing status text to localizable resources or map its status cases to resources in `GeneralPane`. Do not translate internal manager logs.

- [ ] **Step 3: Localize Discord and Stream Deck chrome only**

Translate headings and explanatory copy such as `Connection`, `Application ID`, `Rich Presence`, `Bridge`, `Handshake`, and `Last request`. Keep these values untouched:

- `appModel.discordManager.state.label`
- Discord error payload strings emitted by the manager
- `ControlLogEntry.message`
- `DiscordLogEntry.message`
- diagnostic `area` values such as `Handshake`
- Rich Presence activity strings

Use localized fallbacks such as `Never`, `None`, `No request yet`, and `Not written yet` because those are app UI, not stored log payloads.

- [ ] **Step 4: Localize Advanced and LogPanel controls**

Translate maintenance labels/results, catalog diagnostic labels, severity-filter titles, Clear, empty-filter text, and the visible entry-count footer. Render `entry.area` and `entry.message` verbatim. Keep stored severity raw values stable; expose a separate localized display resource for the filter.

- [ ] **Step 5: Add all Settings catalog entries with comments**

Use `Sender` consistently for user-facing German translations of `channel` and `station`. Use `Senderkatalog` for catalog copy. Keep `Discord`, `Rich Presence`, `Stream Deck`, `AirPlay`, and `GitHub` unchanged.

- [ ] **Step 6: Run Settings tests and inspect compilation warnings**

```bash
swift test --filter 'Settings|Launch at login|App language'
swift build
```

Expected: all Settings tests pass; no call site feeds app-owned UI text through an unlocalized dynamic `String`.

- [ ] **Step 7: Commit Settings localization**

```bash
git add Sources/ILoveMusic/UI/Settings Sources/ILoveMusic/Services/LaunchAtLoginManager.swift Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/SettingsUIAuditTests.swift
git commit -m "feat: localize settings interface"
```

## Task 7: Localize History, Stats, charts, dates, and durations

**Files:**

- Modify: `Sources/ILoveMusic/Support/DurationFormatting.swift`
- Modify: `Sources/ILoveMusic/Support/Extensions.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryListView.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryStatsRootView.swift`
- Modify: `Sources/ILoveMusic/UI/History/HistoryStatsWindowController.swift`
- Modify: `Sources/ILoveMusic/UI/History/StatsLayout.swift`
- Modify: `Sources/ILoveMusic/UI/History/StatsView.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/ChartSelection.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/GenreDonutChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/HourOfDayChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/ListeningTrendChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/StatsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/StatsSummaryStrip.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopArtistsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopChannelsChart.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/TopSongsCard.swift`
- Modify: `Sources/ILoveMusic/UI/History/Charts/WeekdayHourHeatmap.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Create or modify: `Tests/ILoveMusicTests/HistoryStatsUITests.swift`
- Modify: `Tests/ILoveMusicTests/PlayHistoryStatsTests.swift`

- [ ] **Step 1: Re-read the live History tree before editing**

The shared tree contained an uncommitted History redesign when this plan was written. Resolve the exact files first:

```bash
git status --short
rg --files Sources/ILoveMusic/UI/History | sort
```

Preserve the redesigned window controller, responsive layouts, chart selection, and summary strip. Only change user-facing text and locale flow.

- [ ] **Step 2: Add failing formatting and plural tests**

Test German and English explicitly:

```swift
#expect(localizedSongCount(1, language: .english) == "1 song")
#expect(localizedSongCount(2, language: .english) == "2 songs")
#expect(localizedSongCount(1, language: .german) == "1 Song")
#expect(localizedSongCount(2, language: .german) == "2 Songs")
#expect(localizedDayCount(1, language: .german) == "1 Tag")
#expect(localizedDayCount(2, language: .german) == "2 Tage")
```

Add a weekday test that formats the same Monday as `Mon` in English and `Mo` in German. Add a duration test that proves the fallback is not hard-coded `0 Sek.`.

- [ ] **Step 3: Make formatters accept an explicit locale**

Change human-readable formatter signatures to accept `Locale`:

```swift
func formatShortListeningDuration(_ seconds: Double, locale: Locale) -> String
func formatAxisListeningDuration(_ seconds: Double, locale: Locale) -> String
```

Set `DateComponentsFormatter.calendar?.locale` or use a locale-aware `Duration.UnitsFormatStyle` supported by the deployment target. Keep clock formatting numeric. Replace `shortTimeOrDateTime` with a function that receives the active locale for app UI; do not alter ISO-8601 persistence or API parsing.

- [ ] **Step 4: Localize History list and navigation chrome**

Replace the mixed German/English source literals with English source keys. Localize search prompt, channel filter, match count, Today, Yesterday, context-menu actions, unknown-track fallback, empty states, reset action, date headings, and window title. Render artist, song, and station values verbatim.

- [ ] **Step 5: Localize Stats and every chart**

Cover time-range picker options, summary labels, card titles, axes, legends, empty states, chart selection, Top Songs/Artists/Channels, average session text, and chart accessibility descriptions. Replace fixed `Mo/Di/Mi/...` with locale-derived narrow or abbreviated weekday symbols ordered by the chart's Monday-first data model.

- [ ] **Step 6: Add catalog plural variants**

Create English and German `one/other` variants for songs, plays, days, listeners, events, and any count visible in the current redesigned Stats UI. Use catalog interpolation; do not write `count == 1` branches in Swift.

- [ ] **Step 7: Run History and Stats tests**

```bash
swift test --filter 'History|Stats|App language'
swift build
```

Expected: formatting tests pass in both locales and the current redesigned History/Stats UI compiles without reverting any layout work.

- [ ] **Step 8: Commit History and formatting localization**

Stage exact files after reviewing `git status`; do not include unrelated History work owned by another change:

```bash
git add Sources/ILoveMusic/Support/DurationFormatting.swift Sources/ILoveMusic/Support/Extensions.swift Sources/ILoveMusic/UI/History Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/HistoryStatsUITests.swift Tests/ILoveMusicTests/PlayHistoryStatsTests.swift
git diff --cached --stat
git commit -m "feat: localize history and statistics"
```

## Task 8: Complete translations and prove the packaged app

**Files:**

- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`
- Modify: `Tests/ILoveMusicTests/LocalizationCatalogTests.swift`
- Modify: `README.md`

- [ ] **Step 1: Audit remaining user-facing literals**

Run targeted searches:

```bash
rg -n 'Text\(|Label\(|Button\(|Toggle\(|Picker\(|Section\(|LabeledContent\(|\.help\(|accessibility(Label|Hint)|NSMenuItem|window\.title' Sources/ILoveMusic -g '*.swift'
rg -n 'Suche|Heute|Gestern|Kopieren|Stunde|Zeit|Sek\.|Tage| Songs| plays| listeners' Sources/ILoveMusic -g '*.swift'
rg -n 'NSLocalizedString' Sources/ILoveMusic -g '*.swift'
```

Classify every hit as localized app text, verbatim external content, symbol/identifier, or English-only diagnostic/Discord payload. Fix only missed app text. New code should use modern localization APIs, so the final `NSLocalizedString` search remains empty.

- [ ] **Step 2: Finish and review every German translation**

In the catalog, require `state: "translated"` for every German leaf. Check placeholders and plural variables match their English source. Use the agreed glossary: `Sender`, `Senderkatalog`, `Verlauf`, `Wiedergabe`, `Zuhörer`, and `Einstellungen`.

- [ ] **Step 3: Run the complete automated suite**

```bash
swift test
swift build -c release
```

Expected: all existing and localization tests pass with no compiler errors.

- [ ] **Step 4: Build and inspect the standalone app**

```bash
Scripts/build-app.sh
plutil -p .build/ILoveMusic.app/Contents/Info.plist
find .build/ILoveMusic.app/Contents/Resources/ILoveMusic_ILoveMusic.bundle -maxdepth 2 -type f -name 'Localizable.strings' -print
codesign --verify --deep --strict .build/ILoveMusic.app
```

Expected:

- `CFBundleDevelopmentRegion` is `en`.
- `CFBundleLocalizations` contains `en` and `de`.
- the SwiftPM resource bundle contains English and German compiled localization resources.
- code-signature verification succeeds.

- [ ] **Step 5: Perform manual language QA**

Run this matrix:

| Active choice | macOS app language | Expected UI |
| --- | --- | --- |
| System Default | German | German |
| System Default | English | English |
| Deutsch | English | German after restart |
| English | German | English after restart |

For each explicit language, inspect the menu-bar popover, right-click menu, every Settings pane, History list, Stats layouts, chart empty states, confirmations, tooltips, and accessibility labels. Confirm long German text wraps without clipping. Run Xcode pseudolocalization once for layout stress. Confirm Discord Presence and stored diagnostic messages remain English.

- [ ] **Step 6: Document language behavior**

Add a short README section stating that ILoveMusic supports English and German, follows macOS by default, allows an override in `Settings > General > System`, and applies language changes after restart.

- [ ] **Step 7: Review scope and commit**

```bash
git status --short
git diff --check
git diff --stat
git add Sources/ILoveMusic/Resources/Localizable.xcstrings Tests/ILoveMusicTests/LocalizationCatalogTests.swift README.md
git diff --cached --stat
git commit -m "docs: document localized app languages"
```

Do not stage runtime captures, generated `.build` content, screenshots, or unrelated History work.

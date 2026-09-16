# Localization design

## Goal

ILoveMusic supports English and German throughout its app-owned interface. The app follows macOS by default and also offers an in-app language choice. A language change takes effect after the next launch.

## Decisions

- English is the source language.
- The supported choices are `System Default`, `Deutsch`, and `English`.
- The language picker lives in `Settings > General > System`.
- Changing the language saves the preference immediately but does not rebuild the running interface.
- When the saved choice differs from the language active at launch, Settings shows a restart message with `Later` and `Quit ILoveMusic` actions.
- There is no automatic relaunch and no use of the undocumented `AppleLanguages` preference.
- Technical diagnostic messages and Discord Rich Presence payload text stay English.

## Language model and lifetime

Add a Codable `AppLanguage` enum with `system`, `german`, and `english` cases. `UserPreferences` stores the selected value as an optional field so existing state files continue to decode. Missing and unknown values resolve to `system` without invalidating the rest of `state.json`.

`AppModel` captures `activeLanguage` once when it loads preferences. This value does not change during the process lifetime. The bindable Settings value updates the persisted preference. A derived `requiresLanguageRestart` property compares the saved selection with `activeLanguage`.

For `system`, SwiftUI and Foundation use the current macOS language and region. Explicit German and English choices provide a fixed language locale to SwiftUI and to string lookups outside the view tree. All root views receive the active locale:

- the menu-bar popover created by `AppDelegate`
- the dedicated Settings window created by `SettingsWindowController`
- the History and Stats window created by `AppDelegate`

AppKit menu items and window titles use the same active language through explicit localized string lookup.

## String catalog and bundles

Create one catalog at `Sources/ILoveMusic/Resources/Localizable.xcstrings`. It contains the English source strings and German translations. One catalog is enough for the current app size.

The executable is a Swift package target, so localizable APIs point at the target bundle with `#bundle`. The release script already copies the complete SwiftPM resource bundle. It only needs localization metadata in the generated app `Info.plist`: English as the development region and English plus German as supported localizations.

Use translator comments for ambiguous labels, interpolated values, and strings whose visual context is not clear from the English source. Use catalog plural variants for counts instead of branching on singular and plural in Swift.

## Code boundaries

SwiftUI literals use localizable initializers with the package bundle. Shared components that receive app-owned labels accept `LocalizedStringResource`, including Settings rows, status labels, statistic cards, empty states, and reusable menu-bar controls.

Code that must produce `String`, such as `NSMenuItem`, `NSWindow.title`, domain display labels, and user-facing errors, uses `String(localized:bundle:locale:comment:)`. Dynamic content from ILoveMusic servers remains verbatim.

The following app-owned text is localized:

- menu-bar controls, context menus, help text, and accessibility labels
- all seven Settings panes, the Settings sidebar, and Settings window titles
- History, Stats, charts, empty states, and confirmation dialogs
- hotkey action names and conflict summaries
- category names, sorting labels, catalog status, and playback status
- user-facing error summaries
- dates, numbers, durations, weekday labels, and pluralized counts
- the language picker and restart message

The following text stays English or verbatim:

- Discord Rich Presence payloads and activity strings
- diagnostic log entry messages, areas, and protocol values
- `os.Logger` output
- station names and taglines supplied by the service
- artist names and song titles
- URLs, identifiers, technical keys, stream formats, and brand names

The Settings controls around Discord and diagnostics are localized. The runtime data shown inside those controls remains unchanged. User-facing error summaries are localized, but an appended system or server error remains verbatim.

## Settings integration

The current Settings UI has seven sidebar destinations: General, Playback, Discord, Stream Deck, Data, Advanced, and About. Their labels become localizable resources. `SettingsSidebar` and `SettingsWindowController` resolve the same resource so the sidebar and window title cannot drift.

`GeneralPane` adds the language picker to its System section. The picker writes through an `AppModel` binding. When `requiresLanguageRestart` is true, the pane presents a restart notice. `Quit ILoveMusic` calls the normal termination path, which already flushes pending persistence in `applicationWillTerminate`.

`AdvancedPane` localizes section headings, field labels, maintenance results, filters, and empty states. It does not translate `DiscordLogEntry.message`, `ControlLogEntry.message`, or their stored area values. `DiscordPane` follows the same split: settings labels are localized, manager state and Rich Presence payloads remain English.

## Formatting

Remove hard-coded German fragments and hand-built English units. Date, number, and duration formatting receives the active locale. Clock-style durations such as `3:42` stay numeric. Human-readable durations use Foundation formatting and localized fallbacks.

Weekday labels come from locale-aware date formatting instead of a fixed German array. Counts such as songs, plays, days, listeners, and entries use String Catalog plural variants. Percentages retain their numeric meaning and use locale-aware number formatting where Foundation supports it.

The API client's `en_US_POSIX` wire-format locale is not UI and remains unchanged.

## Failure behavior

- Existing state without an app-language field resolves to `system`.
- An unknown stored language value resolves to `system` without losing other preferences.
- A missing German translation falls back to the English source string.
- A language change cannot leave the current process half translated because `activeLanguage` is immutable until restart.
- Quitting from the restart notice uses the normal app shutdown path and flushes queued state writes.

## Verification

Automated tests cover preference migration, all three persistence values, unknown-value fallback, restart detection, bundle resources, catalog completeness, representative plural forms, and release bundle metadata. Existing tests remain green.

Manual QA runs the menu-bar popover, right-click menu, all Settings panes, and the History and Stats window in German and English. System mode is checked with both macOS app languages. QA also covers tooltips, accessibility labels, destructive confirmations, error states, locale-sensitive formatting, long German labels, and pseudolocalization. Discord Presence and diagnostic log messages are checked to confirm that they stay English.


# Settings redesign

## Goal

Replace the current uneven Settings layout with a CodexBar-inspired macOS window. Keep every existing preference and integration behavior intact.

## Reference and design choice

CodexBar uses a custom `NSWindowController`, a full-size transparent title bar, an edge-to-edge material sidebar, compact icon chips, and grouped forms. ILoveMusic will use the same visual principles without copying CodexBar's provider search, sortable rows, resizable sidebar, or title-bar workarounds. Those features solve problems ILoveMusic does not have.

The result is a small custom window rather than a stock SwiftUI `Settings` window or a full CodexBar clone.

## Window

- Create the visible Settings window through an `NSWindowController`.
- Use a default size near 880 by 620 points and a minimum size near 800 by 540 points.
- Keep the window resizable and remember its frame.
- Use `.fullSizeContentView`, a transparent title bar, and native materials.
- Restore the last selected pane when the window opens again.
- Route Command-comma, Settings links, and the menu-bar context menu to the same controller.
- Enter regular activation policy while the window is visible and return to accessory policy after the last auxiliary window closes.
- Keep a minimal SwiftUI `Settings` scene only if macOS needs it to provide the standard app-menu command.

## Navigation

The sidebar has seven destinations:

1. General
2. Playback
3. Discord
4. Stream Deck
5. Data
6. Advanced
7. About

Each row uses a compact 20-point colored symbol chip and native hover and selection states. A hairline divider separates the sidebar from the detail pane. App identity and version sit in a fixed footer below the navigation list, not inside it.

The sidebar has a fixed, practical width. ILoveMusic does not need search, sorting, or a resize handle.

## Detail layout

Every pane uses a grouped SwiftUI `Form` with a transparent scroll background. Labels stay on the left and controls on the right. The detail column has a maximum readable width and remains aligned to the top leading edge when the window grows.

Descriptions appear only when a setting needs clarification. Controls use semantic system colors and the system accent color. The layout must work in light and dark appearances, with increased contrast and reduced transparency.

Dependent controls disable and visually recede when their parent option is off. This applies to Discord options and background update downloads.

## Pane contents

### General

- Launch at login
- Resume the last station on launch
- Station ordering

### Playback

- Default volume and mute control
- Maximum-volume unlock
- Global hotkey enablement
- Per-action hotkey recording, reset, clear, and conflict feedback

### Discord

- Connection status
- Main Rich Presence switch
- Artwork, Listen button, listener count, and station-logo options
- Application ID
- Inline connection error

The Application ID and all child options disable when Discord is off.

### Stream Deck

- Integration status
- Local bridge model
- Last handshake and request
- Last issue
- A short explanation of the file-based handshake and local HTTP bridge

### Data

- Catalog source and refresh state
- Visible and filtered station counts
- Listening-history recording
- Listening-history reset with confirmation

### Advanced

- Manual refresh and cache actions
- Detailed catalog diagnostics
- Discord connection log
- Stream Deck connection log

Logs use compact rows, a severity filter, and a bounded visible list. They must not turn the entire Settings page into a stack of large cards.

### About

- A single free-standing hero row with the app icon, app name, version, and build
- Automatic update checks and background downloads
- Manual update check
- GitHub and ILoveMusic links
- Copyright and project description

Background downloads disable when automatic checks are off.

## State and behavior

The redesign must not rename preference keys or change persistence semantics. Existing `AppModel` bindings keep writing through `PreferencesCoordinator` and `AppStateStore`. Sparkle remains the owner of update settings.

Navigation selection and window frame use their own lightweight persisted values. Opening, closing, and reopening Settings must not reset form state or playback state.

## Errors and destructive actions

Show configuration and connection problems inline in the relevant pane. Do not add success alerts. Cache actions should show small inline completion feedback.

Resetting listening history remains the only destructive Settings action and keeps its confirmation dialog.

## Verification

- Add focused tests for pane routing, persisted selection, dependency state, and Settings-window activation behavior.
- Keep existing preference, hotkey, playback, Discord, and persistence tests passing.
- Build the release `.app`, not only the Swift package executable.
- Open Settings through Command-comma, the menu-bar menu, and in-app Settings links.
- Check all seven panes in light and dark appearances.
- Resize, close, and reopen the window to verify its minimum size, frame restoration, and selected pane.
- Exercise disabled child controls, hotkey recording, history reset, update controls, cache feedback, and both logs.

## Non-goals

- No new preferences or integrations
- No migration of existing preference storage
- No searchable or reorderable sidebar
- No resizable sidebar
- No custom color theme or decorative glass effects
- No changes to the player popover or History and Stats window

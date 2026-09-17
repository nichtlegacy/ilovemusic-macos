# Language Relaunch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relaunch ILoveMusic safely after an in-app language change and package the mechanism in the shipping app bundle.

**Architecture:** The main app launches a dedicated helper with its PID and bundle path, then requests normal AppKit termination. The helper waits for that PID to exit and reopens the exact bundle through `NSWorkspace`, avoiding overlapping app instances.

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, Swift Package Manager, Swift Testing, shell packaging and codesign

---

### Task 1: Relaunch request and tests

**Files:**
- Create: `Sources/ILoveMusic/Support/AppRelauncher.swift`
- Create: `Tests/ILoveMusicTests/AppRelauncherTests.swift`

- [ ] Write tests that inject launch and termination closures, assert `Contents/Helpers/ILoveMusicRelauncher` plus PID and bundle-path arguments, and assert launch failure never terminates the app.
- [ ] Run `swift test --disable-sandbox --filter AppRelauncherTests` and verify the tests initially fail because `AppRelauncher` is absent.
- [ ] Implement `AppRelauncher.restart` with an injectable core and a production wrapper using `Process` and `NSApplication.terminate`.
- [ ] Run the focused tests and verify they pass.

### Task 2: Helper executable and packaging

**Files:**
- Create: `Sources/ILoveMusicRelauncher/main.swift`
- Modify: `Package.swift`
- Modify: `Scripts/build-app.sh`

- [ ] Add the `ILoveMusicRelauncher` executable product and target.
- [ ] Parse exactly a PID and app-bundle path, monitor the original process with a process dispatch source, and call `NSWorkspace.openApplication` only after exit.
- [ ] Copy the helper to `Contents/Helpers`, mark it executable, sign it before the app bundle, and retain deep signature verification.
- [ ] Run `Scripts/build-app.sh` and verify both binaries exist and `codesign --verify --deep --strict .build/ILoveMusic.app` passes.

### Task 3: Settings UI and localization

**Files:**
- Modify: `Sources/ILoveMusic/UI/Settings/Panes/GeneralPane.swift`
- Modify: `Sources/ILoveMusic/Resources/Localizable.xcstrings`

- [ ] Replace the quit action with `AppRelauncher.restart()` and a localized "Restart ILoveMusic" label.
- [ ] Keep the app open and show a localized alert if scheduling the helper fails.
- [ ] Add German translations for the button and failure message.
- [ ] Run localization and settings tests and verify they pass.

### Task 4: Full and live verification

**Files:**
- No source changes expected.

- [ ] Run the complete Swift test suite.
- [ ] Build the release app and verify the helper and all signatures.
- [ ] Install the bundle in `/Applications`, preserving a recoverable backup of an existing installation.
- [ ] Launch the installed app, trigger a controlled helper-based relaunch, and verify the old PID exits and a new PID runs from `/Applications/ILoveMusic.app`.
- [ ] Confirm both repositories remain free of unrelated changes and report the exact installed build.

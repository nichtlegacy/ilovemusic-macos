# Language relaunch design

## Goal

Replace the language-change "Quit ILoveMusic" action with a reliable, user-initiated relaunch while preserving the restart-based localization architecture.

## Design

ILoveMusic ships a small `ILoveMusicRelauncher` executable in `Contents/Helpers`. When the user chooses "Restart ILoveMusic", the app launches that helper with its process identifier and exact bundle URL. Only after the helper starts successfully does ILoveMusic request normal AppKit termination.

The helper waits for the original process to exit and then asks `NSWorkspace` to open the same bundle. This prevents two app instances from overlapping and keeps AppKit's normal termination callbacks intact. It does not use Sparkle internals: Sparkle owns relaunch only while installing an update.

If the helper is missing or cannot launch, ILoveMusic stays running and presents a localized error. The build script packages and signs the helper before signing the outer app bundle.

## Verification

- Unit tests prove the helper path and arguments, termination ordering, and failure behavior.
- The complete Swift test suite and release packaging must pass.
- The packaged helper and outer app signatures must verify.
- A live language change must terminate the old PID, launch a new PID from the installed bundle, and apply the selected language.

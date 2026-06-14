# MiMiNavigator v0.9.9.5.5

Drag-and-drop window targeting reliability update.

## Highlights

- Dragging a file from MiMiNavigator into a browser no longer opens the internal Move or Copy dialog when the browser overlaps the file panel.
- Internal panel drops are accepted only when a MiMiNavigator window is the actual frontmost mouse target at the release point.
- The same visibility check is applied to List and Thumbnail view drag paths.

## Changed

- Replaced manual Core Graphics window-list inspection with AppKit's dedicated `NSWindow.windowNumber(at:belowWindowWithWindowNumber:)` hit-testing API.
- Clear internal directory highlighting as soon as the drag moves over an overlapping window from another application.
- Removed unused runtime exceptions and debug/personal-data entitlements from the signed Release build.

## Fixed

- Prevented an external drag ending with an empty AppKit operation from being reinterpreted as an internal panel transfer based only on screen coordinates.
- Prevented browser uploads and other external drop targets from triggering MiMiNavigator file-operation confirmation behind the destination window.

## Documentation

- Updated the README release badge, download link, and recent changes.
- Corrected the historical `0.9.9.5.4` cloud alias description to the implemented `mimiNavi` plus 8 Base62 characters.

## Validation

- SwiftLint passes for the new window resolver.
- Debug build succeeds with Xcode 26.5 and macOS 26.5.1.
- The signed app retains hardened runtime without JIT, unsigned executable memory, DYLD environment, library-validation, or debug exceptions.
- The release pipeline builds with Developer ID signing and hardened runtime, notarizes with `notarytool`, staples the ticket, validates the ticket, and runs Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.4...v0.9.9.5.5

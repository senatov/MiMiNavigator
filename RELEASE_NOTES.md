# MiMiNavigator v0.9.9.7.8

A focused panel-workflow update with reliable Parent-row drops, seamless cached navigation, exact panel mirroring, and visible release-build progress.

## Highlights

- Drop files onto the fixed Parent row in ordinary local panels to move or copy them to the containing directory.
- Navigate previously visited directories without briefly showing stale rows under the new path.
- Mirror the active panel path, view mode, thumbnail size, filter, selection, and exact column layout into the opposite panel.
- Follow Release compilation live in the terminal while retaining the complete diagnostic log.

## Added

- Preserve the opposite panel's other tabs, tab order, and navigation history when mirroring the active tab.
- Preserve column order, visibility, and widths without a destination autofit pass overwriting the mirrored layout.

## Changed

- Stream filtered signing, compilation, warning, and build-state output during the signed Release build.
- Keep the full unfiltered build transcript in `/tmp/mimi_notarize_build.log` for diagnostics.

## Fixed

- Resolve the fixed Parent row as a local drop destination while preserving archive-root behavior and rejecting filesystem root.
- Load cached directory content before publishing the destination path so path and rows change together.
- Avoid a false appearance of a frozen release caused by buffering the last 40 filtered build lines until `xcodebuild` exits.

## Validation

- Focused navigation and panel-state tests pass on Swift 6.2.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.7...v0.9.9.7.8

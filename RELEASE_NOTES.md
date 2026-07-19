# MiMiNavigator v0.9.9.6.4

File-conflict clarity, operation progress polish, and dependable menu-bar activation.

## Highlights

- Compare equal-size conflict candidates by their actual contents before interpreting timestamps and sizes.
- Present file conflicts in a readable native utility panel with clear status messaging and familiar dimensional controls.
- Restore MiMiNavigator from hidden or minimized states with one primary click on its menu-bar status item.

## Added

- Asynchronous byte comparison for equal-size source and destination files.
- Compact native memory usage beside the animated menu-bar application icon.

## Changed

- File-conflict choices use clearer file cards, emphasized apply-to-remaining control, and the dimensional control language used by Network Neighborhood.
- Operation progress and automatic-close behavior are consistent across copy, move, and delete result windows.
- The menu-bar status item is dedicated to foregrounding the application and exposes no contextual menu.
- Release metadata is updated to version `0.9.9.6.4` and build `133`.

## Fixed

- Cancelling from a conflict prompt no longer opens a zero-files-copied result window.
- Clicking an operation window interrupts its pending automatic close.
- Matching size and modification time no longer imply identical content without a byte comparison.
- Primary-click activation reliably unhides, deminiaturizes, and raises the main window.
- Secondary clicks on the status item no longer trigger toolbar customization or other unintended actions.

## Validation

- The release pipeline performs a clean signed build, custom volume-icon verification, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.3...v0.9.9.6.4

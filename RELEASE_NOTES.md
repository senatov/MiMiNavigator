# MiMiNavigator v0.9.9.7.9

A focused reliability update for deleting files from OneDrive and other macOS File Provider locations.

## Highlights

- Move OneDrive and other File Provider items to the appropriate recoverable trash instead of failing with `NSFeatureUnsupportedError`.
- Keep ordinary local files in the macOS Trash using Finder-compatible recycling.
- Preserve the existing direct-delete behavior for protocol-based remote servers that do not expose a trash facility.

## Changed

- Centralize recoverable deletion through the AppKit workspace recycling API used for Finder-compatible file operations.
- Apply the same recycling behavior to panel deletion, archive source cleanup, drag-and-drop moves, and copy undo.
- Clarify local, cloud-provider, and protocol-based remote deletion behavior in the public documentation.

## Fixed

- Prevent `FileManager.trashItem` from reporting that the local volume has no Trash when deleting items below `~/Library/CloudStorage`.
- Ensure OneDrive removals are propagated by its File Provider domain while retaining a recoverable local Trash item when supported by macOS.

## Validation

- The Debug application build succeeds on Apple silicon.
- A live recycle probe in the affected OneDrive folder moved the item successfully to the local macOS Trash.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.8...v0.9.9.7.9

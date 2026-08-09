# MiMiNavigator v0.9.9.7.0

A reliability release for drag-and-drop selection and directory refreshes after external filesystem changes.

## Highlights

- Dragging from a scrolled file list now transfers the application or file directly under the pointer.
- Returning from AppCleaner, Finder, Terminal, or another application forces a disk-backed refresh of both visible panels.
- The fixed `..` parent-navigation strip no longer shifts DnD row indexing.

## Changed

- Resolve list drag sources through the native scroll view's document coordinates instead of deriving a row from the unscrolled panel frame.
- Use only real displayed files for DnD hit-testing because parent navigation now lives in a separate fixed strip.
- Force panel scans when MiMiNavigator becomes active so a recent directory cache cannot hide external deletions.
- Include document coordinates and the resolved filename in drag diagnostics.

## Fixed

- Dragging an item after scrolling no longer transfers a different row from the unscrolled position.
- Removing applications through AppCleaner no longer leaves the visible panel and DnD source list out of sync after activation.
- DnD no longer has a persistent one-row offset caused by the detached parent entry.

## Validation

- Updated Swift sources pass frontend parsing and whitespace validation.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.9...v0.9.9.7.0

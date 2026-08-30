# MiMiNavigator v0.9.9.7.7

A focused navigation and release-reliability update that keeps mounted media from disrupting active panels and makes path completion easier to understand.

## Highlights

- Separated the four most recently selected destinations from actual subdirectories in path autocomplete.
- Prevented newly mounted local volumes and updater images from automatically focusing and navigating the left panel.
- Kept mounted media discoverable through the Volumes menu and Finder Sidebar.
- Hardened the release pipeline against silent SwiftPM resolver stalls.

## Added

- Show recent destinations in a dedicated autocomplete section with restrained native headers.
- Preserve section-specific identities when a recent destination is also a child of the entered directory.

## Changed

- Keep trailing-slash autocomplete scans inside the explicitly requested directory.
- Retain mount and unmount observation only in UI surfaces that list available volumes.
- Record complete package-resolution diagnostics and retry one stalled resolution attempt.

## Fixed

- Avoid unexpected panel focus and path changes when macOS mounts removable media or temporary updater disk images.
- Terminate the package resolver process tree after prolonged inactivity or user interruption.
- Restore generated version files after interrupted or completed release runs.

## Validation

- The application passes the macOS Debug build on Swift 6.2.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.5...v0.9.9.7.6

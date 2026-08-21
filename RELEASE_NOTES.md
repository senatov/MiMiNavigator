# MiMiNavigator v0.9.9.7.3

A substantial interface and reliability update that makes MiMiNavigator more compact, informative, and consistent with its dual-panel identity.

## Highlights

- Refined the main window, file panels, toolbar customization, Settings, command bar, tabs, filters, and empty states while preserving the application's dimensional button style.
- Rebuilt the menu bar experience with a recognizable MiMiNavigator icon, clearer typography, live connection information, diagnostics, and current system errors.
- Added macOS-safe keyboard defaults and clearer shortcut guidance in Settings and documentation.
- Moved reusable search, media metadata, external-tool, and network discovery services into shared Swift packages.

## Changed

- Keep zebra striping across the full panel height and improve focus, selection, column headers, navigation controls, spacing, and loading feedback.
- Keep directories alphabetically ordered independently of the selected file sort column and direction.
- Add professional column-layout presets and improve the quick-filter presentation.
- Preserve previous `/tmp/MiMiNavigator*.log` files for later diagnostics instead of overwriting the last session log.
- Refresh third-party dependency declarations, licenses, acknowledgements, About information, and README documentation.

## Fixed

- Clear file selection when clicking unused space in the active panel.
- Close Settings reliably without flashing or requiring a second attempt.
- Update Connections immediately after disconnecting a mounted network volume.
- Restore menu bar icon click behavior for showing and hiding the main window.
- Correct title-bar spacing, branding alignment, build labeling, and command-bar edge insets.

## Validation

- All extracted package test suites pass.
- The application passes a Debug build after the package migration.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.2...v0.9.9.7.3

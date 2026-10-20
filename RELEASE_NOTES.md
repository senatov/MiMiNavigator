# MiMiNavigator v0.9.9.8.7

This release improves runtime diagnostics and avoids repeated work when showing large directories.

## Highlights

- Record active and recent directory scans, size calculations, and column Autofit when the main queue is delayed. Include memory footprint, thread count, and probe gaps to make performance reports easier to investigate.
- Report the mode, entry count, elapsed time, and outcome of recursive directory-size scans.
- Stop the automatic fallback size scan when a normal scan exceeds its budget. Keep the folder accessible and show its size as unavailable until its cache is invalidated.
- Avoid reloading and republishing favorites each time the breadcrumb toolbar appears, and remove noisy constructor logging.

## Validation

- Debug build and running-app checks cover navigation and breadcrumb interactions.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.6...v0.9.9.8.7

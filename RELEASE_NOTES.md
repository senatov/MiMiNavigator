# MiMiNavigator v0.9.9.8.5

This release restores file metadata in List view and adds Finder columns for information macOS exposes.

## Highlights

- Fill Created, Added, Group, and other file metadata consistently during local directory scans.
- Show **Last Open** from Spotlight's last-used date, matching Finder for files with an indexed date.
- Add optional, sortable **Version**, **Comments**, and **Tags** columns alongside the existing List columns.
- Fit a newly enabled column to its content and refresh visible rows when the column selection changes.

## Other changes

- Use native text sizes in Favorites rows so names and paths follow macOS text settings.
- Keep archive session state and temporary extraction folders in ArchiveKit, including dirty tracking and cleanup for nested archives.
- Rebuild public MiMiKits binary packages from the current private package sources.

## Validation

- Scanner metadata tests and the source-free Debug application build passed.
- The release pipeline checks the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.4...v0.9.9.8.5

# MiMiNavigator v0.9.9.5.7

Per-tab panel view persistence update.

## Highlights

- Each panel tab remembers its own List, Preview, or Tree view.
- Switching tabs immediately restores the selected tab's configured view.
- View configuration persists with restored tabs across application restarts.

## Changed

- Store panel view mode in each `TabItem` instead of sharing one mode across an entire panel side.
- Make new tabs inherit the active tab's view and duplicated tabs retain the source view.
- Preserve the configured view during directory and archive navigation.
- Update release metadata to version `0.9.9.5.7` and build `125`.

## Fixed

- Changing List, Preview, or Tree mode in one tab no longer changes every tab on the same panel.
- Returning to a previously configured tab no longer shows the last mode selected in another tab.

## Documentation

- Updated `README.md` with the current release highlights and download link.
- Added the complete `0.9.9.5.7` entry to `CHANGELOG.md`.

## Validation

- Debug build succeeds with the release changes.
- `git diff --check` passes for all edited files.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.6...v0.9.9.5.7

# MiMiNavigator v0.9.9.5.9

Multi-Rename, reliable navigation, keyboard access, and interface consistency update.

## Highlights

- Rename multiple files or folders with masks, counters, replacements, case conversion, conflict preview, rollback, and keyboard control.
- Navigate reliably through Favorites, tabs, search, archives, history, mounted connections, and file operations without stale panel listings.
- Use consistent Tab navigation and button feedback throughout toolbars, settings, network controls, and modal dialogs.

## Added

- Multi-Rename supports selection and directory scopes, separate name and extension masks, counters, plain or regex replacement, case conversion, and live conflict validation.
- Safe two-phase renaming includes rollback and refreshes the focused panel after completion.
- Network discovery recognizes additional devices and services.

## Changed

- Route all directory entry points through one synchronized navigation flow.
- Use the same copy and move confirmation dialog for drag-and-drop and toolbar operations.
- Apply consistent glass button styling and keyboard-focus feedback across dialogs.
- Update release metadata to version `0.9.9.5.9` and build `127`.

## Fixed

- Prevent stale panel listings caused by scanner and path-update races.
- Keep Tab and Shift-Tab focus inside popup dialogs.
- Avoid repeated Keychain prompts for saved network credentials.
- Restore clear active-panel zebra contrast and focus-aware row updates.
- Hide windows immediately during termination and remove unsafe temporary JSON cleanup.

## Validation

- Public update metadata and authenticated asset redirect verified through `miminavi.tech`.
- Debug and notarized Release builds complete successfully.
- `git diff --check` passes for all edited files.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.8...v0.9.9.5.9

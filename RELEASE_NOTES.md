# MiMiNavigator v0.9.9.7.1

A responsiveness and reliability release for directory-first sorting, stable column sizing, and panel controls.

## Highlights

- Every sortable column orders directories independently while keeping them above files.
- Valid directory sizes are hydrated from SQLite in batches before the first sort, reducing RAM pressure and repeat work.
- Column autofit pauses during loading and metadata recalculation, preventing loops and visible width jitter.
- Sort buttons, Autofit On/Off, scrollbar jump controls, panel restoration, and autocomplete window ownership are restored.

## Changed

- Apply the selected Name, Date Modified, Size, Kind, Owner, or item-count comparator separately to directories and files.
- Re-sort published rows when calculated metadata changes without losing the permanent directory-first grouping.
- Use a bounded memory cache backed by persistent SQLite size records for fast revisits and immediate sort changes.
- Present lightweight raised sort indicators with a blue active direction and a slightly taller header.
- Validate submodule cleanliness and remote reachability before starting a release.

## Fixed

- Restore header click handling and the Autofit On/Off submenu after the regressed header/scroll merge.
- Make size sorting work on the first click in large Library folders as well as smaller directories.
- Prevent loading-time autofit tasks from repeatedly resizing columns.
- Keep scrollbar tracks between the top and bottom jump buttons without overlap.
- Preserve both panel paths across restart and prevent mount auto-connect from replacing the restored right panel.
- Keep the autocomplete panel attached to MiMiNavigator instead of covering unrelated applications.

## Validation

- Updated Swift sources pass frontend parsing and whitespace validation.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.
- Release preflight verifies that every recorded submodule commit is clean and available from its remote.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.0...v0.9.9.7.1

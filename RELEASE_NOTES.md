# MiMiNavigator v0.9.9.6.6

A substantially more capable Find Files workflow with safer cleanup presets, multi-selection, and clearer feedback.

## Highlights

- Search with separate streamlined and advanced interfaces, a persistent results divider, and a subdued criteria summary in the bottom status line.
- Review large stale files, empty old folders, and recognizable leftovers from removed applications through focused templates.
- Select multiple results and open, copy, move, or move them to Trash directly from the search window.

## Added

- App leftovers discovery across safe top-level entries in Application Support, Caches, Preferences, Logs, Saved Application State, and LaunchAgents.
- Installed-application name and bundle-identifier matching to exclude data belonging to applications that remain installed.
- Spotlight-backed indexed searches with automatic `find` fallback for criteria Spotlight cannot represent.
- Folders-only and empty-folder search modes, result-table column customization, quick one-, two-, and three-year age filters, and persisted search preferences.
- Live result batching, bounded result counts, throttled sorting, and reduced filesystem metadata work for large searches.

## Changed

- Search and Advanced now have distinct, predictable roles while retaining all previous search options.
- Search criteria and options use a two-column layout; the criteria/results divider remains draggable and remembers its position.
- Active template and option styling is quieter and less alarming, with explicit template state that remains stable during a search.
- Documentation screenshots now show the current dual-panel interface, App leftovers search, and Hotkeys settings.

## Fixed

- App leftovers can no longer turn into a single-file search because a file happened to be selected in the active panel.
- App leftovers no longer searches only Application Support and no longer returns arbitrary files from the panel directory.
- Command-A selects Find Files results instead of being intercepted by the main panel.
- iCloud, sandbox containers, protected macOS locations, and installed-application data are excluded from cleanup candidates.
- Trash operations report successful and failed items accurately, and completed operations refresh the result list.
- Empty directories found by search can be moved to Trash.
- The search-window splitter no longer moves the whole window, and narrow layouts no longer clip the item-type control.
- Progress labels remain readable across light, dark, accent, and increased-contrast appearances.

## Validation

- Debug builds completed successfully throughout development.
- The release pipeline performs a clean signed build, custom volume-icon verification, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.5...v0.9.9.6.6

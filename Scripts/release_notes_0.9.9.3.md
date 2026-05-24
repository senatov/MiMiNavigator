# MiMiNavigator v0.9.9.3

View-mode parity, Preview drag-and-drop, Tree view, and autosave release.

## Highlights
- **Added**: Tree view mode with lazy expandable directories and table-style metadata columns.
- **Fixed**: `Ctrl+A` in Preview mode now marks files through the same AppState-backed selection model as List mode.
- **Fixed**: drag-and-drop from Preview mode to the opposite panel now routes through `DragDropManager` and opens the normal transfer confirmation.
- **Changed**: List, Preview, and Tree modes now share sorting headers and panel keyboard navigation callbacks.
- **Added**: periodic configuration autosave every 30 seconds for state, panel paths, tabs, sort state, preferences, and startup cache.

## Download
Notarized DMG - drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.2...v0.9.9.3

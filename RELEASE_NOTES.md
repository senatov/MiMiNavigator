# MiMiNavigator v0.9.9.5.2

Navigation, panel layout, file-operation feedback, and Finder-style context menu update.

## Highlights

- Panel tabs now live in the bottom status strip with wider glass styling, distinct active-state colors, restored paths, and compact hover details.
- The parent-directory strip is now a full-width glass control with reliable AppKit hover tracking, animated feedback, readable active colors, and an upward-navigation cursor.
- Opening archives and navigating or refreshing directories now preserves a valid selection when possible and otherwise selects the first real row.
- File and folder context menus now react live while Option is held, using native AppKit alternate menu items without closing or rebuilding the menu.
- Get Info is consistently available for files, folders, and multiple selections.

## Fixed

- Fast single-file moves and copies no longer reuse or complete a stale archive progress panel.
- Successful atomic moves, including drag-and-drop moves after archive creation, no longer show an unnecessary yellow progress popup.
- Table headers have improved height and vertical alignment so column labels no longer touch the top border.

## Documentation

- Refreshed application screenshots and documented the current panel, navigation, selection, and context-menu behavior.
- Release metadata updated to version `0.9.9.5.2`, build `123`.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.1...v0.9.9.5.2

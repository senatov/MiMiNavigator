# MiMiNavigator v0.9.8.3 — Release Notes

## Highlights

- Finder-style sidebar with History, favorites, cloud storage, mounted volumes, Network, AirDrop, and Trash
- Console action is available across R-Menus, including files, folders, selections, panel background, and sidebar items
- Ejectable local mounts can be unmounted from the Finder Sidebar R-Menu
- Autofit layout was reworked so left and right panels fit independently and keep the measured Name column readable
- Privacy prompts are reduced by avoiding protected Finder favorites refresh on every sidebar open

## Fixed

- Replaced the broken Recents URL with MiMiNavigator's own History window
- Removed duplicate and non-working iCloud Drive sidebar entries
- Fixed right-panel autofit skips caused by shared resize throttling
- Fixed Size/date/count width measurement by using the same monospaced-digit font as the row renderer
- Fixed autofit application so calculated fixed-column widths are applied atomically

## Changed

- Split Finder Sidebar and Autofit code into smaller focused files
- Added privacy purpose strings for protected folders, volumes, app data, Music, and Photos
- Updated marketing version to `0.9.8.3`
- Updated build number to `111`

## Build & Release

- Version: `0.9.8.3`
- Build: `111`
- Tag: `v0.9.8.3`
- Artifact: notarized DMG

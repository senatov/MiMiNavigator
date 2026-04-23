# MiMiNavigator v0.9.8 — Release Notes

## Highlights

- Toolbar Customize dialog redesign with a clearer card-based layout
- First right-click now reliably brings the customize panel to the front
- `Done` closes the dialog on the first click
- Drag-to-remove in Toolbar Customize now works as advertised
- Toolbar visibility persistence cleaned up for customizable vs. fixed items

## Fixed

- Opening Toolbar Customize from a toolbar right-click now waits for menu tracking to settle, then re-asserts front-most ordering
- Closing Toolbar Customize no longer races with `bringAuxiliaryPanelsToFront()`
- Dropping a visible toolbar item into Available Items now hides it
- `menuBarToggle` no longer affects customizable visibility counts or minimum-visible-button logic

## Changed

- Refined toolbar customize chips, palette cells, and insertion markers
- Updated README and changelog for the 0.9.8 release

## Build & Release

- Version: `0.9.8`
- Tag: `v0.9.8`
- Artifact: notarized DMG

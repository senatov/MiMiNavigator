# MiMiNavigator v0.9.9.0.0

Preview navigation stability and release pipeline hardening update.

## Highlights

- Keep panels on their selected mounted-volume path during Preview mode refreshes.
- Suppress automatic fallback from temporarily unavailable `/Volumes/...` paths to `/Volumes`.
- Publish GitHub releases only when the release remains editable and the DMG asset is fully uploaded.

## Added

- Release validation now checks that GitHub reports `isImmutable=false` after upload.
- Release validation now confirms the uploaded DMG asset is present and in the `uploaded` state.

## Changed

- Update release metadata to version `0.9.9.0.0` and build `128`.
- Document the editable-release requirement in the release pipeline notes.

## Fixed

- Prevent scanner recovery from moving a panel to `/Volumes` when a mounted-volume subpath is temporarily unavailable.
- Skip Preview-mode partial publishes when the scan result no longer matches the panel's current path.
- Skip stale full scan publishes so old background results cannot replace a panel's current listing.

## Validation

- Debug build succeeds before release preparation.
- Release script rejects immutable releases and incomplete DMG asset uploads.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.9...v0.9.9.0.0

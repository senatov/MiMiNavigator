# MiMiNavigator v0.9.8.5 — Release Notes

## Highlights

- Scanner and archive internals now live in package targets instead of duplicated app-side files
- Mounted volume scanning is more stable and uses leaner metadata reads
- File operation progress reports live byte progress for many-small-file copy workloads
- ArchiveKit exposes the process and format API needed by the app UI
- Remote connection, SFTP hidden-file filtering, dialog focus, and top-row navigation fixes are included

## Fixed

- Fixed ArchiveKit access-control errors for app-side archive progress and archive format UI
- Fixed AES ZIP extraction behavior
- Fixed mounted-volume scan and exit edge cases
- Fixed SFTP hidden-file filtering when `showHiddenFiles` is disabled
- Fixed remote connection authentication handling
- Fixed Open With associations and Get Info routing
- Fixed dialog focus and top-edge keyboard navigation regressions

## Changed

- Scanner logic is routed through `ScannerKit`
- Archive logic is routed through `ArchiveKit`
- File copy progress uses hybrid many-small-file planning with live byte reporting
- History and favorites dialogs were resized and refined
- Updated marketing version to `0.9.8.5`
- Updated build number to `115`

## Build & Release

- Version: `0.9.8.5`
- Build: `115`
- Tag: `v0.9.8.5`
- Artifact: notarized DMG

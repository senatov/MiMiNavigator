# MiMiNavigator v0.9.8.5 — Release Notes

## Highlights

- Geo-tagged photos now show a small orange globe badge directly on the file icon
- Media Info now surfaces GPS map links near the top of the panel
- Breadcrumbs now show the filesystem root segment and copy the real local path
- Scanner and archive internals now live in package targets instead of duplicated app-side files
- Mounted volume scanning is more stable and uses leaner metadata reads
- File operation progress reports live byte progress for many-small-file copy workloads
- ArchiveKit exposes the process and format API needed by the app UI
- Remote connection, SFTP hidden-file filtering, dialog focus, and top-row navigation fixes are included

## Fixed

- Fixed geo-tag badge refreshes when the NSTableView file panel redraws or reuses rows
- Fixed breadcrumb Copy path so local paths copy the real filesystem path instead of the display path
- Fixed ArchiveKit access-control errors for app-side archive progress and archive format UI
- Fixed AES ZIP extraction behavior
- Fixed mounted-volume scan and exit edge cases
- Fixed SFTP hidden-file filtering when `showHiddenFiles` is disabled
- Fixed remote connection authentication handling
- Fixed Open With associations and Get Info routing
- Fixed dialog focus and top-edge keyboard navigation regressions

## Changed

- Geo-tag badge rendering is shared across SwiftUI and AppKit panel paths, with an orange compact badge
- Media Info header and bottom controls keep their height when the window is resized
- Breadcrumb back, forward, and parent controls use clearer arrowshape symbols
- Scanner logic is routed through `ScannerKit`
- Archive logic is routed through `ArchiveKit`
- File copy progress uses hybrid many-small-file planning with live byte reporting
- History and favorites dialogs were resized and refined
- Updated marketing version to `0.9.8.5`
- Updated build number to `116`

## Build & Release

- Version: `0.9.8.5`
- Build: `116`
- Tag: `v0.9.8.5`
- Artifact: notarized DMG

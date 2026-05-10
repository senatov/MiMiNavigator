# MiMiNavigator v0.9.8.6 — Release Notes

## Highlights

- Geo-tagged photos now show a compact orange globe badge directly on the file icon
- Media Info now surfaces GPS map links near the top of the panel
- Breadcrumbs now show the filesystem root segment and copy the real local path
- The geotag badge refreshes correctly through NSTableView row reuse and scanner republishes

## Fixed

- Fixed geo-tag badge refreshes when the NSTableView file panel redraws or reuses rows
- Fixed breadcrumb Copy path so local paths copy the real filesystem path instead of the display path

## Changed

- Geo-tag badge rendering is shared across SwiftUI and AppKit panel paths, with an orange compact badge
- Media Info header and bottom controls keep their height when the window is resized
- Breadcrumb back, forward, and parent controls use clearer arrowshape symbols
- Updated marketing version to `0.9.8.6`
- Updated build number to `117`

## Build & Release

- Version: `0.9.8.6`
- Build: `117`
- Tag: `v0.9.8.6`
- Artifact: notarized DMG

# MiMiNavigator v0.9.8.4 — Release Notes

## Highlights

- SMB shares no longer fail when MiMiNavigator cannot create `/Volumes/<share>` directly
- Toolbar connection actions now open connected SMB sessions in the active panel
- Active app-managed remote sessions are shown in the Finder-style sidebar Locations list
- Disconnect restores affected panels from navigation history instead of blindly returning to a saved folder
- Copy conflict dialogs now separate Existing and Incoming files with clearer action labels
- macOS service metadata files such as `.DS_Store` and AppleDouble `._*` are skipped during copy planning

## Fixed

- Fixed SMB connect failures caused by sandbox/system permission errors while creating `/Volumes/<share>`
- Fixed dropdown navigation for local SMB mount paths containing spaces, such as `Application Support`
- Fixed missing sidebar visibility for app-managed SMB mounts outside `/Volumes`
- Fixed ambiguous copy conflict wording and overlapping progress HUD behavior
- Fixed copy plans so `.DS_Store`, `._*`, `.localized`, `.Spotlight-V100`, `.TemporaryItems`, `.Trashes`, `.fseventsd`, `.DocumentRevisions-V100`, and `.apdisk` are not copied

## Changed

- SMB mount points are now created under MiMiNavigator's Application Support mount folder unless an existing system `/Volumes` SMB mount can be reused
- File operation progress is hidden while a conflict dialog waits for a user decision
- Completion OK button animation in the file operation progress panel was removed
- Updated marketing version to `0.9.8.4`
- Updated build number to `112`

## Build & Release

- Version: `0.9.8.4`
- Build: `112`
- Tag: `v0.9.8.4`
- Artifact: notarized DMG

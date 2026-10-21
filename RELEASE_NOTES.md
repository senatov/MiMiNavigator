# MiMiNavigator v9.9.1

This release makes files from SFTP directories and archives available to other macOS applications through drag and drop. The public version now uses three numeric components.

## Highlights

- Drag files from SFTP panels to Finder and apps such as Telegram. Remote files are prepared locally before the external drag starts.
- Drag extracted archive entries to other applications as local files.
- Retry a remote drag after cancelling the first drop without downloading the same selection again during the short staging cache period.

## Validation

- The Debug build completed successfully.
- A live SFTP drag opened Telegram's attachment preview. After cancelling it, the same file was dragged again and appeared in Finder.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.7...v9.9.1

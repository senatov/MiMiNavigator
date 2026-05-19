# MiMiNavigator v0.9.9.2

Remote connection fixes and release workflow hardening.

## Highlights
- **Fixed**: deleting files from SFTP/FTP/SMB panels now uses the active remote provider instead of macOS `FileManager.trashItem`, which cannot handle remote URLs.
- **Fixed**: long connection failures are formatted into compact, readable summary/detail sections.
- **Changed**: connection error popups are constrained to the app window width, preventing full-screen-wide dialogs.
- **Changed**: the Connect dialog keeps the parsed host name when URL-style input is entered in the Name field.
- **Changed**: the Connect dialog now uses the app's custom 3D button style, with Connect as the default action.
- **Fixed**: notarized release upload now detects immutable GitHub releases during preflight before build and notarization.

## Download
Notarized DMG - drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.1...v0.9.9.2

# MiMiNavigator v0.9.9.1

Remote mount stability and release upload safety update.

## Highlights
- **Fixed**: Vuduo2/app-managed network mount refresh no longer triggers expensive watcher behavior.
- **Changed**: remote directory metadata can show partial size and first-level child count within a short timeout budget.
- **Changed**: slow remote size scans stop per branch and keep the best known partial result.
- **Changed**: Connections toolbar control now matches standard toolbar sizing, font, and selected accent text color.
- **Fixed**: notarized release upload no longer deletes an existing GitHub release/tag after an asset upload failure.

## Download
Notarized DMG — drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.0...v0.9.9.1

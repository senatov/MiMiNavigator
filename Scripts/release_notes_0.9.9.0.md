# MiMiNavigator v0.9.9.0

File operations engine overhaul — clipboard paste, directory copy fix, progress panel UX.

## Highlights
- **Fixed**: directory copy failed with POSIX error 2 (missing target subdirectory)
- **Fixed**: cancel showed "✅ Done" instead of dismissing the panel
- **Changed**: clipboard paste now uses FileOpsEngine with progress, strategies, conflict resolution
- **Changed**: FileOpsEngine split from 616-line monolith into 9 focused files
- **Changed**: TC-style progress panel — auto-dismiss on cancel/success, OK only on errors
- **Changed**: log files wiped on each app launch

## Download
Notarized DMG — drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.8.9...v0.9.9.0

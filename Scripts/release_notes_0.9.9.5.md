# MiMiNavigator v0.9.9.5

Drag-and-drop file operation stability, breadcrumb polish, managed mount cleanup, and progress panel hardening release.

## Highlights
- **Fixed**: conflict dialogs after internal drag-and-drop moves no longer hang. The progress panel now reads keyboard data only from keyboard events, avoiding AppKit assertions during modal alerts.
- **Fixed**: successful-operation auto-close is no longer cancelled by passive mouse movement or unrelated main-window events.
- **Fixed**: middle splitter hover highlighting is restored after the external drop overlay changes.
- **Fixed**: copy/move now preflights destination write access before entering long file-manager operations.
- **Changed**: internal drag state is cleared before transfer work starts, so confirmation and conflict dialogs do not compete with an active drag session.
- **Changed**: breadcrumbs keep useful path context, preserve separators, and expand shortened segments on hover.
- **Changed**: managed SMB mount cleanup is safer, and stale history/favorite entries are shown as unavailable instead of being opened.
- **Changed**: progress panel and file context menu internals were split into smaller focused files for maintenance.
- **Build**: version `0.9.9.5`, build `121`.

## Download
Notarized DMG - drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.4...v0.9.9.5

# MiMiNavigator v0.9.9.7.4

A focused workspace update adding persistent file previews, a clearer Commander-style action bar, and unified in-app feedback.

## Highlights

- Added a persistent, resizable Preview pane that follows the active panel selection and keeps essential file metadata visible.
- Refined the bottom command bar with clearer separation between icons, shortcuts, and action names while preserving MiMiNavigator's dimensional control style.
- Introduced a shared toast and banner system with scoped queues, actionable connection errors, and concise success feedback.

## Added

- Toggle Preview from the toolbar, the Show and View menus, or with `⇧⌘P`.
- Remember Preview visibility and width between application sessions.
- Display native previews for selected files together with kind, size, modification date, and source path.
- Show connection failures as in-app banners with endpoint details, readable recovery guidance, and a Retry action.
- Show short success notifications for completed connections and relevant Cloud Share actions.

## Changed

- Give bottom command buttons more room, a stronger border, a clearer top highlight, and a short dimensional shadow.
- Use crisp SF Symbols and lighter system typography for command icons, shortcuts, and labels.
- Separate command icon, shortcut, and title with restrained dividers instead of bright internal tiles.
- Route main-window and Connect to Server notifications through one shared mechanism while keeping each notice in its originating window.

## Removed

- Remove the legacy `ConnectErrorPopupController` after migrating connection diagnostics to the unified banner system.

## Validation

- The application passes a Debug build with Swift 6.2 after the Preview and notification integrations.
- Release metadata and public download documentation are synchronized for `v0.9.9.7.4`.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.3...v0.9.9.7.4

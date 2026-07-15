# MiMiNavigator v0.9.9.6.3

Network intelligence, History cleanup, dialog layout, and DMG presentation update.

## Highlights

- Identify LAN devices more accurately with optional Fing Local API enrichment and online MAC vendor lookup.
- Keep History globally unique by directory, retaining only the newest valid visit.
- Present confirmation and archive dialogs at readable HIG-compliant sizes without clipped content or edge-hugging buttons.

## Added

- Fing Local API settings with Keychain-backed API key storage, connection testing, and device merging by MAC, IP, or name.
- Manufacturer and model details in Network Neighborhood rows and device information popups.
- Future plans for Nextcloud/WebDAV remote panels and CloudKit settings synchronization.

## Changed

- Unknown Apple mobile Bonjour devices are shown honestly as iPhone / iPad until stronger evidence identifies the model.
- The DMG uses a correctly sized background with a centered installation arrow, top instruction, and verified custom volume icon.
- Release metadata is updated to version `0.9.9.6.3` and build `132`.

## Fixed

- Remove all older History occurrences of a directory instead of preserving one duplicate per calendar day.
- Prevent long copy/move confirmation content from being clipped by conflicting fixed-size constraints.
- Restore standard margins and minimum sizing in the Create Archive panel.
- Preserve the custom DMG volume icon through Finder styling, conversion, notarization, and stapling.

## Validation

- The release pipeline performs a clean signed build, custom volume-icon verification, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.2...v0.9.9.6.3

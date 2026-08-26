# MiMiNavigator v0.9.9.7.6

A focused Commander-interface update with crisper controls and a persistent, inspectable history of file-operation messages.

## Highlights

- Added a numbered history for the 32 most recent in-app notices, available from a dedicated yellow rivet beneath the Test Build badge.
- Persisted notice history across application sessions with timestamps and available source and destination paths.
- Refined bottom tabs into attached folder-sheet shapes that match the Commander toolbar more closely.
- Kept light native toolbar typography crisp by removing fractional pressed-state text scaling.

## Added

- Keep a bounded recent-message archive without serializing transient action closures.
- Restore notice title, detail, timestamp, type, and semantic icon after restart.
- Show copy and move origins and destinations when the operation already provides those URLs.
- Open and close the history with the same top-edge animation as ordinary messages.

## Changed

- Render notice text and paths with the user's configured panel and accent colors while preserving secondary timestamp styling.
- Present history as a scrollable stack of the same pale-yellow cards used for individual notices.
- Replace the Rename pencil with the conventional text-cursor rename symbol.
- Increase tab height and use the same 14-point light system typography as the bottom action bar.

## Fixed

- Keep the history rivet inside the fixed toolbar hit-test area and give it a larger invisible click target.
- Prevent pressed toolbar labels from becoming blurry on fractional pixel boundaries.
- Keep the Test Build badge passive so only its dedicated rivet toggles message history.

## Validation

- The application passes the macOS Debug build on Swift 6.2.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.5...v0.9.9.7.6

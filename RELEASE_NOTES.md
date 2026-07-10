# MiMiNavigator v0.9.9.6.1

Cloud Share+Link reliability, credential security, and development badge polish update.

## Highlights

- Keep successful Google Drive and Dropbox sharing usable when TinyURL is unavailable.
- Prevent duplicate cloud copies after shortener or Dropbox API failures.
- Store Dropbox refresh tokens in Keychain with automatic legacy migration.
- Present a sharper, brighter, more dimensional DEV BUILD toolbar badge.

## Changed

- Google Drive image sharing now uses standard Drive view URLs accepted by TinyURL.
- Dropbox refresh tokens now use Keychain as their primary storage and migrate from the legacy credentials file.
- The development badge now uses a sharper multicolor cat, lighter material, refined type, and stronger convex depth.
- Update release metadata to version `0.9.9.6.1` and build `130`.

## Fixed

- Fall back to original Google Drive and Dropbox links when TinyURL cannot shorten them.
- Remove Dropbox copies created by failed operations and recover existing shared-link races.
- Preserve Dropbox refresh tokens during temporary network failures and reauthorize only revoked credentials.
- Reject invalid non-HTTP cloud API and OAuth responses.
- Stop attempting to create a Google Drive `Public` folder inside a read-only desktop mount.

## Validation

- Cloud Share+Link changes pass source and whitespace validation.
- The release pipeline performs a clean signed build, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.0...v0.9.9.6.1

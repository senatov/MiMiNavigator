# MiMiNavigator v0.9.9.7.2

A hotfix restoring downloads and installation through the built-in software updater.

## Highlights

- The Install Update button can download the signed DMG again.
- Direct update downloads continue to support both proxy-relative and absolute HTTPS asset URLs.

## Changed

- Resolve release-proxy asset paths against `https://miminavi.tech` before passing them to URLSession or NSWorkspace.
- Reject download URLs that do not resolve to HTTPS.

## Fixed

- Fix `unsupported URL` when the update API returns `/api/github/download?...` instead of a complete URL.
- Restore both automatic installation and the manual asset-download action.

## Validation

- Updated Swift sources pass frontend parsing and whitespace validation.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.
- The resolved proxy URL was verified against the published GitHub release asset.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.1...v0.9.9.7.2

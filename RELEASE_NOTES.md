# MiMiNavigator v0.9.9.8.4

This release makes error reporting easier to find and improves SFTP connection recovery when a host is briefly unreachable.

## Highlights

- Make **Report an Error** a larger, raised button with a bug icon in the Feedback window.
- Give the Feedback window more room so its actions and explanatory text remain clear.
- Retry an SFTP connection once when every resolved address initially fails because the network has no route to the host.

## Fixed

- Offer a concise, privacy-filtered error report for remote connection failures before opening Blogger.
- Preserve the immediate error response for authentication, SSH negotiation, and unrelated connection failures.

## Validation

- The Debug app builds successfully with the updated Feedback window and SFTP retry.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.3...v0.9.9.8.4

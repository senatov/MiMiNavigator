# MiMiNavigator v0.9.9.7.10

A reliability update for auxiliary windows and media conversion, with clearer diagnostics for long-running operations.

## Highlights

- Reopening an auxiliary window replaces stale or hidden content with the context of the latest action.
- Media conversion protects the source file, including symbolic-link and hard-link aliases.
- Failed or cancelled GIF size reduction restores the previously converted result; recovery conflicts preserve the backup and record its location.

## Changed

- Run Lottie/TGS decompression and capability checks asynchronously, continuously draining process output to avoid blocking the interface.
- Record process identifiers, arguments, elapsed time, exit status, bounded output tails, and progress checkpoints for long-running conversions.
- Add background main-queue responsiveness checks and window counts to memory diagnostics.
- Build releases in isolated temporary directories without closing Xcode or deleting shared developer caches.

## Fixed

- Prevent overlapping conversions and stale process callbacks from mixing progress state.
- Preserve the final diagnostic output when an external conversion tool fails.
- Allow Debug XCTest hosts to run alongside the application without triggering the single-instance exit.

## Validation

- Thirteen targeted tests passed, covering dialog state, source-file aliases, process output, file redirection, and GIF recovery conflicts.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.9...v0.9.9.7.10

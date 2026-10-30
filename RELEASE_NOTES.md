# MiMiNavigator v0.9.1.5

This release adds automatic, review-first cleanup assistance to Find Files.

## Improvements since v0.9.1.4

- Add a dedicated Cleanup tab. The background scan starts with MiMiNavigator, waits until the app is out of focus and system load and thermal conditions are low, and revisits eligible locations without a manual start.
- Inspect the home directory and writable local volumes for exact file and leaf-folder duplicates, old installers, temporary files, and old empty folders. Compare file contents across eligible local volumes. Exclude system and cloud locations, development projects, virtual environments, and Time Machine destinations.
- Identify old PID files for processes that are no longer running. When Apple Intelligence is available, use its on-device Foundation Models API to review possible leftovers from uninstalled applications; unavailable models leave this category unclassified.
- Store directory checkpoints, file metadata, content hashes, candidate snapshots, and AI verdicts in SQLite so scans can resume after a restart and avoid repeated work.
- Keep deletion manual: review and mark individual items or duplicate groups, retain at least one copy in every group, and recheck candidate contents and conditions immediately before moving selected items to Trash.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Users of v0.9.1.2 must install a macOS 27 release manually before later updates can use the OS-aware feed.
- Open the DMG and drag MiMiNavigator to Applications.

## Validation

- The Debug build and focused tests for scan resumption, cross-root indexing, changed-duplicate rejection, and cleanup exclusions passed on macOS 27.
- The Cleanup tab and automatic startup were checked in the running Debug app. Apple Intelligence reported `modelNotReady` on the validation Mac, so a live model verdict could not be exercised; deterministic cleanup categories remain available.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.4...v0.9.1.5

---

# MiMiNavigator v0.9.1.4

This update refines the main-window titlebar on macOS 27 or newer.

## Highlights

- Bring the titlebar closer to Safari's compact proportions with a shorter native toolbar and smaller app title.
- Group actions in consistent capsules with thin dividers and centered, accessible button hit areas.
- Keep the optional icon-and-text toolbar presentation while tightening icon-only spacing.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Users of v0.9.1.2 must install a macOS 27 release manually before later updates can use the OS-aware feed.
- Open the DMG and drag MiMiNavigator to Applications.

## Validation

- The Debug build passed on macOS 27. The titlebar was inspected in the running app, and the Hidden Files action was exercised and restored.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.3...v0.9.1.4

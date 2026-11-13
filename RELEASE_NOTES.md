# MiMiNavigator v0.9.1.8

This release improves Telegram sticker conversion and refreshes the About window.

## Improvements since v0.9.1.7

- Render animated Telegram `.tgs` stickers and Lottie JSON with the bundled TelegramMessenger/rlottie engine. Export GIF, first-frame PNG, MP4, or WebM without installing Python or python-lottie.
- Keep FFmpeg as the output encoder and show a clear error if the bundled renderer is missing.
- Add rlottie and cwebp to the dependency inventory, update resolved Swift package versions, and remove the obsolete python-lottie setup requirement.
- Use the standard macOS system font with restrained color accents in About; remove duplicate architecture text and an outdated Swift version label.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Users of v0.9.1.2 must install a macOS 27 release manually before later updates can use the OS-aware feed.
- Open the DMG and drag MiMiNavigator to Applications. FFmpeg remains required for TGS output encoding; static WebP encoding requires cwebp.

## Validation

- The bundled renderer was built for arm64 and a compressed Lottie test animation was rendered to PNG and GIF.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.7...v0.9.1.8

---

# MiMiNavigator v0.9.1.7

This release adds safer review and broader developer-cache discovery to Cleanup.

## Improvements since v0.9.1.6

- List large Xcode and package-manager caches only after 180 days without changes and above 100 MB; active Xcode indexes, source trees, and any cache containing an excluded or unreadable path are not offered.
- Check open paths for processes belonging to the current user immediately before moving selected items to Trash. If the check finds an open file or cannot complete, Cleanup leaves the selection untouched.
- Label sensitive, stale, duplicate, and review-first candidates so the reason for extra care is visible in the list.
- Report locations skipped by access and metadata-reading failures in the scan status.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Users of v0.9.1.2 must install a macOS 27 release manually before later updates can use the OS-aware feed.
- Open the DMG and drag MiMiNavigator to Applications.

## Validation

- The Debug build passed on macOS 27. Automated tests were not run for this release preparation.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.6...v0.9.1.7

---

# MiMiNavigator v0.9.1.6

This release improves copy and delete feedback for removable volumes.

## Improvements since v0.9.1.5

- Keep the progress window centered at a readable width and show the current file path, destination, and per-file results.
- Build destination directory trees in the background and check whether files still missing at the destination can fit before starting a copy, including retries after an interrupted or incomplete copy.
- Explain when the volume is too full to move deleted items to Trash and how to free space while keeping deleted items recoverable.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Users of v0.9.1.2 must install a macOS 27 release manually before later updates can use the OS-aware feed.
- Open the DMG and drag MiMiNavigator to Applications.

## Validation

- The Debug build passed on macOS 27.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.5...v0.9.1.6

---

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

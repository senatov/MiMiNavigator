# MiMiNavigator v0.9.2.2

This update expands archive support and improves tabs, volume navigation, and file-operation feedback.

- Browse, extract, and create CBZ comic archives. Open ARC and ZOO archives with Homebrew's `unar`. RAR extraction supports `unrar`, `unar`, and 7-Zip. RAR creation uses the separately installed RARLAB command-line tool.
- Use a more compact bottom tab strip, choose tab fonts and appearance, and restore the previous column widths after a manual Auto Fit.
- See volume capacity and filesystem details, eject eligible volumes, and try the experimental Kindle Documents and Android SFTP shortcuts.
- Set when routine file operations ask for confirmation. Deletion previews show where items are, how many are selected, and whether their size is still being measured.
- Automatic Cleanup skips the home Music library and Apple TV libraries.

Requires macOS 27 or later and Apple silicon. Open the DMG and drag MiMiNavigator to Applications.

[Supported archive formats](https://github.com/senatov/MiMiNavigator/blob/v0.9.2.2/GUI/Docs/Supported_Archive_Formats.md) · [Changes since the original v0.9.2.1 build](https://github.com/senatov/MiMiNavigator/compare/090a5f36...v0.9.2.2)

---

# MiMiNavigator v0.9.2.1

This update improves remote file handling, first-run setup on shared Macs, and navigation in the two panels.

## Improvements since the published v0.9.2.0 build

- Copy and move files within one SFTP server or between connected SFTP servers. Remote uploads are verified before the destination is published.
- Drag SFTP files and folders from the list to Finder and other file destinations as real downloaded content instead of remote path text.
- Keep ordinary named folders visible when dotfiles are hidden, even if Finder has set a hidden attribute. Show and hide dotfiles consistently during scans and live updates.
- Follow panel history in order with Back and Forward, enlarge navigation controls, and simplify connection and other menu actions with clearer icons and disabled states.
- Avoid redundant directory publications and column measurements when scanned content has not changed.
- Respect the owner of an existing Homebrew prefix during first-run tool installation, give standard users actionable guidance, and write installation logs under `/tmp`.
- Store the single-instance lock in each user's own temporary directory so another account's lock does not prevent startup.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Open the DMG and drag MiMiNavigator to Applications. First-run command-line setup may require help from an administrator or the Homebrew prefix owner.

## Validation

- ScannerKit tests, the Debug build, and a source-free build against the rebuilt MiMiKits binaries passed. Live SFTP drag-and-drop on the reporting Mac remains to be checked.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.2.0...v0.9.2.1

---

# MiMiNavigator v0.9.2.0

This release adds optional Cloudflare R2 media sharing and reduces unnecessary work when switching tabs or returning to the app.

## Improvements since v0.9.1.9

- Upload image, video, and audio files to a configured public Cloudflare R2 bucket and copy the direct public URL after the upload succeeds. R2 starts disabled and requires your own bucket and S3 credentials.
- Enable Google Drive, Dropbox, and Cloudflare R2 independently in Cloud Share+Link. Turning a provider off keeps its credentials and previously shared files.
- Make the active tab easier to identify, shorten tab transitions, and update the default appearance, toolbar, shortcuts, and Full Disk Access onboarding action.
- Coalesce repeated panel refreshes on app activation, delay scans for fresh cached tabs during rapid switches, and avoid repeating unchanged automatic column measurements.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Open the DMG and drag MiMiNavigator to Applications.
- R2 links are public while the bucket and uploaded object remain public; remove the object or disable public access to revoke one.

## Validation

- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.9...v0.9.2.0

---

# MiMiNavigator v0.9.1.9

This release improves SFTP navigation and makes remote file transfers safer.

## Improvements since v0.9.1.8

- Keep the two SFTP panels independent when navigating and refreshing folders, and use each panel's own connection to open remote files.
- Restore remote-to-remote copy and move between directories, including the reported Belege and UMTAUSCH paths.
- Open remote PDFs by double-clicking or pressing Enter after downloading them to a unique temporary location.
- Transfer SFTP files in bounded chunks. Upload to a temporary remote name, verify its size, and publish it only after completion. Preserve an existing destination if upload fails, and delete a moved source only after the destination succeeds.
- Require unit tests in CI while keeping UI tests advisory pending a reliable hosted remote fixture.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains the final macOS 26-compatible release.
- Open the DMG and drag MiMiNavigator to Applications.

## Validation

- Debug build and unit tests were run with Xcode 27.3 on macOS 27. The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.8...v0.9.1.9

---

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

# MiMiNavigator v0.9.9.6.9

A performance and resource-efficiency release focused on lower idle memory, faster directory revisits, and less background disk activity.

## Highlights

- File rows now share one context-menu graph instead of retaining a full SwiftUI/AppKit menu responder for every row.
- Recently visited directories can be restored immediately from a bounded memory snapshot while FSEvents keeps the listing current.
- Watched local directories no longer receive an unconditional full scan every five minutes.
- Icon and QuickLook backing memory is constrained with smaller render sizes and explicit cache-cost limits.
- SQLite cache parameters now provide predictable page-cache, mapping, and WAL behavior.

## Changed

- Moved the list context menu from individual file rows to the shared lazy stack while preserving file, directory, and marked-selection actions.
- Reduced list icon generation from 128 points to 32 points and bounded file, symlink, and hidden-item image caches by count and estimated byte cost.
- Corrected Retina QuickLook requests so display dimensions are not doubled before applying the backing scale.
- Added a 10,000-file global budget to the recent-directory LRU in addition to its per-listing limit.
- Publish fresh directory snapshots before scanning and skip the scan when an active watcher guarantees live updates.
- Extend periodic integrity scans to 30 minutes for watched paths while retaining the five-minute safety fallback for paths without FSEvents.
- Configure CacheKit with a 2 MiB SQLite page cache, 16 MiB mmap limit, and 256-page WAL checkpoints.

## Fixed

- Incremental filesystem changes now update the recent-directory cache instead of leaving a snapshot stale until the next full scan.
- FSEvents continuity failures, dropped events, and watched-root changes now request a complete directory refresh.
- Per-row context-menu responders no longer multiply SwiftUI platform menu items, SF Symbol graphs, accessibility objects, and responder retain cycles.
- Composed symlink and hidden-directory icons can be evicted under memory pressure.

## Validation

- FileModelKit tests: 8 passed.
- CacheKit tests: 4 passed.
- Full Debug build completed successfully.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.8...v0.9.9.6.9

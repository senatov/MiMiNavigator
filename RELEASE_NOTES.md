# MiMiNavigator v0.9.9.6.8

A focused archive workflow and persistent-cache reliability release.

## Highlights

- Drag files or a marked selection from an archive onto the fixed To-Parent strip to copy or move them beside the archive.
- Clear green-and-blue contact feedback now links the To-Parent strip, drag preview, and marked-file badge before the mouse button is released.
- Moving content out of an archive reliably marks the active archive session as modified and offers to repack it on exit.
- Persistent SQLite caches perform fewer writes and invalidate directory sizes after shared file operations.

## Added

- The To-Parent strip is a real archive drop destination backed by the shared Copy/Move confirmation and `FileOpsEngine`.
- AppKit geometry-based drop detection makes repeated archive transfers independent of SwiftUI drop-target timing.
- SQLite cache health diagnostics, path-prefix invalidation, and explicit dirty-session diagnostics.

## Changed

- Cache hits throttle `lastAccess` updates instead of writing to the WAL on every read.
- Cache pruning deletes stale entries in bounded batches and waits briefly for transient SQLite contention.
- Copy, move, and delete invalidate related directory-size entries in memory and SQLite, including affected ancestors.
- Archive drag previews use a green contact surface, blue border, confirmation badge, and green multi-file counter over To-Parent.

## Fixed

- Repeated To-Parent drops no longer animate without creating a transfer operation.
- Archive drops now show the standard Copy/Move question and shared operation progress.
- Moving a file out of an archive no longer leaves the original entry inside after the archive is repacked.
- Dirty tracking now uses the stable archive URL instead of a `CustomFile` logical origin path.
- Missing archive sessions produce an explicit warning instead of a false “marked dirty” success message.
- Directory-size results are no longer retained after shared filesystem mutations make them stale.

## Internal

- `CacheKit` gained throttled access touches, a busy timeout, batched pruning, prefix removal, and `PRAGMA quick_check` health reporting.
- CacheKit tests cover persistence, expiry, pruning, access throttling, prefix removal, and database health.
- Directory-size invalidation lives in a dedicated extension and remains under the project file-size limit.

## Validation

- All CacheKit tests pass.
- Full Debug builds complete successfully.
- The release pipeline performs a clean signed Release build, DMG verification, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.7...v0.9.9.6.8

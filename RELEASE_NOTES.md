# MiMiNavigator v0.9.9.6.5

Reliable external editing and fast timestamped Temp-Backup archives.

## Highlights

- Open documents reliably in an already running Visual Studio Code instance.
- Create timestamped ZIP backups directly from F3 for selected files and folders.
- Confirm large backup jobs before they begin and show cancellable progress.

## Added

- `Temp-Backup` replaces the former F3 View action while preserving existing custom F3 bindings.
- Timestamped archive names in the form `name.extension.YYYY-MM-DD-HHmm.zip` with collision-safe numbering.
- Size and file-count preflight for backup jobs, including bounded inspection of very large directories.
- Detailed `[ExternalOpen]` and `[Backup]` diagnostics.

## Changed

- Multiple selected items are compressed directly with the system ZIP tool instead of being copied into a temporary staging directory first.
- The bottom toolbar uses the native full-color ZIP document icon for Temp-Backup.
- Open With responsibilities are separated into focused source files below the project’s 400-line limit.
- Release metadata is updated to version `0.9.9.6.5` and build `134`.

## Fixed

- Repeated Open, Open With, and F4 requests no longer disappear silently when Visual Studio Code is already running.
- VS Code receives documents through its `--reuse-window` IPC path, with Launch Services retained as a logged fallback.
- Launch Services failures now produce diagnostics and a visible application error instead of silent failure.
- Large multi-item backups no longer require nearly twice the source size in temporary disk space.

## Validation

- Debug build completed successfully before release preparation.
- The release pipeline performs a clean signed build, custom volume-icon verification, notarization, stapling, and Gatekeeper assessment.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.6.4...v0.9.9.6.5

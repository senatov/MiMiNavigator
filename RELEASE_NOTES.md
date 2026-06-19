# MiMiNavigator v0.9.9.5.6

External tools and IntelliJ IDEA compare reliability update.

## Highlights

- IntelliJ IDEA directory and file compare now launches through a fresh macOS app instance.
- The README now has a dedicated External Utilities and Tools chapter for installation and setup.
- Diff tool documentation now explains IntelliJ IDEA command syntax, installation options, detected paths, and licensing.

## Changed

- Launch the built-in IntelliJ IDEA diff preset with `open -n <IntelliJ.app> --args diff <left> <right>`.
- Keep other diff tools on their existing direct launcher paths.
- Document recommended Homebrew setup for KDiff3, `unar`, `p7zip`, FFmpeg, gifski, and python-lottie.
- Update release metadata to version `0.9.9.5.6` and build `124`.

## Fixed

- Prevented new IntelliJ compare requests from being routed into a stale JetBrains backend process that can remain alive after the diff window is closed.

## Documentation

- Added IntelliJ IDEA setup notes to `GUI/Docs/DiffTools_Setup.md`.
- Added a README tool matrix with links to Homebrew, KDiff3, IntelliJ IDEA, FFmpeg, gifski, python-lottie, cloud desktop clients, rclone, and detailed internal docs.

## Validation

- `git diff --check` passes for the edited files.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.5...v0.9.9.5.6

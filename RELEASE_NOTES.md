# MiMiNavigator v0.9.9.5.8

Secure automatic update installation and daily update checks.

## Highlights

- MiMiNavigator can now download, verify, install, and relaunch into a new release automatically.
- Update checks run shortly after startup and every 24 hours while the app remains open.
- The update dialog shows release notes and opens the product What's New page during installation.

## Added

- Download notarized DMG updates from the public MiMiNavigator update service.
- Validate the published SHA-256 digest, Developer ID team, bundle identifier, release version, and Gatekeeper assessment before installation.
- Replace the installed application after shutdown, retain a rollback copy until replacement succeeds, and relaunch automatically.
- Check for new releases shortly after app launch and every 24 hours.
- Open `https://miminavi.tech/#download` in the default browser when installation begins.

## Changed

- Use `miminavi.tech/api/github/release` for public release metadata instead of anonymous GitHub API access.
- Display complete GitHub release notes, DMG size, and live installation status in the Software Update window.
- Update release metadata to version `0.9.9.5.8` and build `126`.

## Fixed

- Update checks no longer report “No releases found” when GitHub rejects anonymous repository API requests.
- Future releases no longer require users to download, mount, and manually replace MiMiNavigator.

## Validation

- Public update metadata and authenticated asset redirect verified through `miminavi.tech`.
- Debug and notarized Release builds complete successfully.
- `git diff --check` passes for all edited files.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.7...v0.9.9.5.8

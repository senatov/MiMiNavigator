# MiMiNavigator v0.9.1.3

This is the first release that requires **macOS 27 or newer** on Apple silicon. [v0.9.1.2](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.1.2) remains available for macOS 26.

## Highlights

- Keep view modes and the menu toggle visible in narrower windows, with individual toolbar actions available through native overflow.
- Open file and folder context menus without reading cloud tokens. Choosing unrelated actions such as Media & Convert no longer triggers a Dropbox Keychain password prompt.
- Reduce work in large directories by bounding column-width sampling, skipping unnecessary flat-folder publication work, hashing large scan results away from the main actor, and reusing sorted scan order for file tables.
- Check the downloaded application's minimum macOS version before an in-app update replaces an installed copy. Missing or malformed version metadata also cancels installation.
- Validate the signed app version and macOS deployment target before DMG packaging. CI now propagates Xcode build failures correctly.

## Compatibility and installation

- Requires macOS 27 or newer and Apple silicon. The application bundle and executable declare the macOS 27 minimum.
- The v0.9.1.2 updater cannot report the host OS. It continues to receive the final macOS 26 release, including when running on macOS 27. To move from v0.9.1.2 to this release, download the DMG manually. Later updates use the OS-aware feed.
- Finder's drag-to-Applications installation does not run the in-app compatibility check. Check the macOS requirement before copying the app.

## Validation

- Focused large-directory and update compatibility checks passed on macOS 27.0.1. The 19,367-file VS Code extension assets directory was used as a read-only fixture during development.
- The release pipeline verifies the signed bundle, notarized DMG, stapled ticket, and Gatekeeper assessment before publishing.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.2...v0.9.1.3

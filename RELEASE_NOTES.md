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

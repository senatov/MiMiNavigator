# MiMiNavigator v0.9.9.8.2

This release adds a compact live resource monitor to the top toolbar, improves toolbar consistency and readability, and gives DMG and ZIP files distinct, meaningful icons.

## Highlights

- View MiMiNavigator memory usage and thread count in independent live sparklines beside the Test Build badge.
- Enable or disable the RAM and thread graphs separately and choose independent 3–60 second refresh intervals in General Settings.
- Recognize DMG installers with a dedicated disk-image icon and ZIP archives with the cabinet-style archive icon.
- Use a lighter, sharper top-toolbar style aligned with the bottom command bar.

## Changed

- Run the RAM and thread samplers on separate low-overhead timers with timer tolerance to reduce unnecessary wakeups.
- Query only the process metric required by each graph instead of collecting every metric on every refresh.
- Place resource graphs directly beside the central build badge and preserve live updates when preferences change.
- Use shared toolbar surfaces and restrained semantic colors while keeping SF Symbols monochrome and Retina-sharp.
- Replace the bitmap feedback emoji with a native vector SF Symbol.
- Add complete MIT attribution for the Hop-inspired compact sparkline implementation to About and third-party notices.

## Fixed

- Eliminate blurred toolbar text and icons caused by hierarchical symbol rendering, fractional font sizes, translucent foregrounds, and persistent per-button decoration.
- Align the build badge, resource graphs, and action groups to a consistent height and vertical baseline.
- Keep RAM and thread labels left-aligned and readable without heavy black typography.
- Preserve backward compatibility when existing preferences files do not contain the new graph visibility or interval settings.

## Validation

- The focused Debug build completes successfully and the updated toolbar and General Settings have been checked in the running application.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.1...v0.9.9.8.2

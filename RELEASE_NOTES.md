# MiMiNavigator v0.9.9.8.6

This release improves button readability and makes file operations more reliable.

## Highlights

- Give action buttons in dialogs, search, multi-rename, and Settings the same raised shape, readable text, divider, and colored symbol.
- Replace pale orange action icons with saturated blue or purple symbols that remain distinct on light backgrounds.
- Rework About links and dependency rows with clearer typography, appropriate icons, and full-size button targets.
- Make the button border, corner, and shadow controls in Settings affect the shared button style and its live preview.

## Reliability

- Prevent copy and directory-scan races and use asynchronous subprocess handling for Git status.
- Detect Git availability on a clean macOS installation and give useful guidance when Command Line Tools are missing.

## Validation

- Debug build and a visual check of the Settings button preview passed.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.5...v0.9.9.8.6

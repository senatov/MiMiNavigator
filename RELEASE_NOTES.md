# MiMiNavigator v0.9.9.8.1

This release makes the source checkout buildable without access to the private MiMiKits source repositories and improves media preview and auxiliary-window presentation.

## Highlights

- Public checkouts resolve prebuilt MiMiKits XCFrameworks from GitHub Release assets, while private library implementation sources remain outside the application repository.
- Image previews use a thin blue border; video previews use a thin dark-green border.
- Media & Convert and related standalone windows reliably open above the main MiMiNavigator window while remaining normal application windows.

## Changed

- Require macOS 26 or later and Apple silicon across the application and all binary package manifests.
- Move reusable file sorting, archive capability, network probing, and share-result mapping logic into the private kits.
- Add scripts for building, verifying, and switching between binary and private source package configurations.
- Add binary-distribution license terms and the AGPL additional permission required for public builds.
- Update repeated release runs to replace the DMG asset and refresh the existing GitHub Release title and notes.

## Fixed

- Reassert standalone-window ordering after the originating menu event completes, preventing auxiliary panels from occasionally appearing behind the main window.
- Skip obsolete submodule validation when the public checkout has no `.gitmodules` file.

## Validation

- A fresh public-consumer build downloaded the binary XCFrameworks without GitHub credentials and completed successfully.
- Targeted FileModelKit, ArchiveKit, and NetworkKit tests passed.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.10...v0.9.9.8.1

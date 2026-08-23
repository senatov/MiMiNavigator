# MiMiNavigator v0.9.9.7.5

A broad design and architecture update focused on clearer search, predictable macOS window behavior, and maintainable presentation boundaries.

## Highlights

- Expanded Find Files with PDF and Microsoft Office text extraction, clearer advanced filters, compact paths, and panel-consistent result styling.
- Made standalone windows, sheets, popovers, progress panels, and system file pickers respect their originating window without floating above unrelated applications.
- Added read-only Git state badges and directory summaries without turning MiMiNavigator into a Git client.
- Established shared semantic typography, dimensional controls, section headers, dialog structure, and accessibility behavior across the application.

## Added

- Search text in PDF, DOCX, XLSX, PPTX, and compatible document containers using native and package-contained extraction paths.
- Show modified, untracked, ignored, and conflicted Git states in file panels together with a concise directory summary.
- Display active Advanced Search filters as compact chips with incompatibility guidance and a focused reset action.
- Use explicit presentation roles and lifecycle policies for standalone windows, decisions, transient popups, and progress UI.
- Cover presentation policies, advanced-search normalization, and media-conversion phases with focused tests.

## Changed

- Align Find Files typography, rows, columns, empty states, and controls with the main dual-panel workspace.
- Prioritize file names in search results and truncate long locations to the available column width while preserving the full path for inspection.
- Persist manually edited Find Files criteria and normalize folder-only presets before content searches.
- Use light semantic typography for ordinary labels and shortcuts while reserving stronger hierarchy for genuine headings.
- Respect Increased Contrast and Reduce Motion, and provide clearer VoiceOver descriptions and keyboard-adjustable split controls.
- Route archive, OAuth, external-tool, file-operation, and system-panel decisions through asynchronous window-scoped presentation.
- Separate media conversion, search execution, scanning publication, remote operations, and drag geometry from presentation state.

## Fixed

- Prevent Find Files and other standalone windows from disappearing permanently behind the main window or competing for focus.
- Prevent application-wide modal loops and floating panels from blocking unrelated MiMiNavigator windows or other applications.
- Restore content searches after applying incompatible folder presets.
- Keep manual Search In edits instead of restoring an older path on the next session.
- Cancel media conversion safely while awaiting fallback decisions and prevent duplicate progress lifecycles.

## Validation

- FavoritesKit and NetworkKit package tests pass on Swift 6.2.
- The application is validated with the macOS Debug build and focused presentation-state tests.
- The release pipeline performs a clean Developer ID build, signed DMG creation, notarization, stapling, and Gatekeeper verification.

## Download

The DMG is signed and notarized by Apple and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.7.4...v0.9.9.7.5

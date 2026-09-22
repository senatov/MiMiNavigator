# MiMiNavigator v0.9.9.8.3

This release restores readable and consistent auxiliary-window controls, prevents accidental file operations from Preview clicks, and returns window and Dock presentation to predictable macOS behavior.

## Highlights

- Use the same readable Commander button design in dialogs, sheets, auxiliary windows, and the bottom command bar.
- Open auxiliary windows at their full designed size in the center of the invoking main window when no saved frame exists.
- Keep restored auxiliary windows inside the visible area after display-layout changes.
- Select Preview thumbnails normally without immediately triggering a move or copy operation.

## Changed

- Remove the redundant Open With toolbar action and customization-palette entry while retaining the complete Open With submenu in the file context menu.
- Let macOS manage the Dock icon without runtime image replacement or forced Dock-tile redraws.
- Replace oversized root and container glass effects in Connect to Server and other dialogs with stable readable surfaces.
- Share one command-button implementation for typography, icon sizing, dividers, padding, borders, hover feedback, and disabled states.

## Fixed

- Prevent ordinary Preview clicks and selection attempts from being interpreted as drag-and-drop file operations.
- Restore working Copy, Move, Cancel, Convert, Save, Connect, and other dialog actions after visual modifiers intercepted their input.
- Keep metadata headings and field labels readable instead of rendering them with faint undersized typography.
- Prevent additional windows from opening clipped, inheriting invalid coordinates, or disappearing beyond the current screen layout.
- Remove application-side Dock-icon manipulation that could leave the icon translucent during a session.
- Remove uncontrolled glass layers that expanded into large translucent ellipses across Connect to Server.

## Validation

- Debug builds complete successfully after the interaction, button, window-placement, and toolbar changes.
- Copy and Connect to Server dialogs were checked in the running application, and test file operations were cancelled before execution.
- The release pipeline verifies the arm64 executable, Developer ID signature, signed DMG, Apple notarization, stapling, and Gatekeeper assessment.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.8.2...v0.9.9.8.3

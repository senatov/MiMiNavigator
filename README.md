
<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="Preview FrontEnd"
    title="Logo"
    style="max-width: 80%; height: auto; border: 2px; border-radius: 8px;" />
</div>


> 💡 ***If you are only interested in the source code implementation of this app, you can explore it directly here:***
> <span style="color:#8B0000; font-weight:bold;">👉 [MiMiNavigator / GUI / Sources](https://github.com/senatov/MiMiNavigator/tree/master/GUI/Sources)</span>


---
### MiMiNavigator - MacOS File manager with two panels
## (NOT READY YET, still under Development)



[![Swift Version](https://img.shields.io/badge/Swift-6.2-blue.svg)](https://swift.org)
[![Xcode Version](https://img.shields.io/badge/Xcode-26-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Framework](https://img.shields.io/badge/Framework-SwiftUI-blueviolet.svg)](https://developer.apple.com/xcode/swiftui/)
[![Mac Studio](https://img.shields.io/badge/Device-Mac_Studio_M2Max-orange.svg)](https://www.apple.com/mac-studio/)
[![Memory](https://img.shields.io/badge/RAM-32_GB-brightgreen.svg)]()
[![Encryption](https://img.shields.io/badge/Encryption-Enabled-green.svg)]()
[![Programming](https://img.shields.io/badge/Type-Free_Programming-lightblue.svg)]()
[![Shareware](https://img.shields.io/badge/License-Freeware-yellow.svg)]()


---
##     Overview
MiMiNavigator is a macOS file manager built with Swift and SwiftUI.
The repository is organized around an Xcode project with sources under `MiMiNavigator/` and basic tests in `MiMiNavigatorTests` and `MiMiNavigatorUITests`.

---
## 

<div style="text-align: center;" >
  <img
    src="GUI/Docs/Preview1.png"
    alt="Preview FrontEnd"
    title="Preview"
    alt="Preview FrontEnd"
    aria-dropeffect="true"
    style="max-width: 100%; height: auto; border: 2px solid #133347ff; border-radius: 4px;" />
</div>

---
##

<div style="text-align: center;" >
  <img
    src="GUI/Docs/Preview2.png"
    alt="Preview FrontEnd"
    alt="Preview FrontEnd"
    aria-dropeffect="true" 
    title="Preview"
    style="max-width: 100%; height: auto; border: 2px solid #133347ff; border-radius: 4px;" />
</div>



---
### General structure

Key directories inside `MiMiNavigator/`:

- **App** entry point and logging setup. The application reads a `.version` file, sets up a shared model container, and displays a main split view UI with a log viewer button. The code uses SwiftyBeaver for logging.

- **States** observable classes and actors that hold runtime state. `AppState` tracks the current directories and selected files, while `DualDirectoryScanner` scans both panels using timers and async updates.

- **Models** data structures such as `CustomFile`, an entity representing files or directories, and `FileSingleton`, an actor maintaining left/right file lists for SwiftUI updates.

- **Views** SwiftUI views for file panels, the top menu bar, and toolbar. `TotalCommanderResizableView` composes the main UI with a draggable divider and toolbar buttons for actions like view, edit, copy, and delete.

- **BreadCrumbNav** editable path controls and breadcrumb navigation.

- **Favorite** scans frequently used directories and mounted volumes to show a favorites tree.

- **Menus** menu item models and top menu rendering.

Other resources include asset catalogs, entitlements files, and a `refreshVersionFile.zsh` script that updates the `Gui/curr_version.asc` string.


---
### Important aspects

- **Concurrency** Directory scanning and file updates are handled by actors (`DualDirectoryScanner`, `FileSingleton`) and async tasks to keep the UI responsive.

- **User preferences** Window sizes, panel widths, and other state are stored using `UserPreferences`(UserDefaults wrappers).

- **Logging** `LogMan` sets up **SwiftyBeaver** console and file logging with custom icons for log levels.

- **Customization** Many UI components (menu buttons, path control, tooltip) are implemented as reusable **SwiftUI** views.

---
### Getting started

1. Clone the repository and open `MiMiNavigator.xcodeproj` in Xcode.

2. Build and run. The README outlines basic installation steps and features such as dual panel navigation and periodic directory scanning.

3. The main entry point is `MiMiNavigatorApp` which initializes logging and sets up the main view hierarchy. Explore `AppState` and `DualDirectoryScanner` to understand how directory changes propagate to the UI.

---
### Learning pointers

- **SwiftUI layout and modifiers** Many views use custom modifiers and gestures (e.g., `onHover`, drag gestures for the divider).

- **Actors and concurrency** `DualDirectoryScanner` demonstrates using timers inside an actor for periodic work.

- **AppKit interop** Some components rely on `NSWorkspace`, `NSAlert`, and other AppKit APIs for macOS 16.4 specific functionality.

- **Persistent data** The app uses SwiftData `ModelContainer` for future persistence, though currently the `Item`model is minimal.

This project is still under active development ( NOT READY YET  per the README) but provides a clear example of a SwiftUI macOS application with multithreading, logging, and modular UI components.

---
## Current Stage

-  Support for macOS 26 with Swift 6.2 beta5.
-  Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
-  Modular and reusable components for top navigation.
-  Integrated file management actions including copy, rename, and delete.
-  Full Total Commander submenu structure recreated.
-  Dynamic output naming in shell utilities.
-  Dual-panel interface for managing files and directories.
-  Automatic UI updates when directory contents change.



---
## Requirements

- macOS 26 or later
- Swift 6.2
- Xcode 26.2 beta


---
##  Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/username/MiMiNavigator.git
    cd MiMiNavigator
    ```
2. Open the project in Xcode:
    ```sh
    open MiMiNavigator.xcodeproj
    ```
3. Build and Run through Xcode or with the command:
    ```sh
    xcodebuild -scheme MiMiNavigator -configuration Debug CODE_SIGNING_ALLOWED=YES
    ```
4. Check sources
    ```sh
    * periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator *
    ```


---
 ## Usage

1. Launching: Open the application and set directories for dual-panel mode.
2. File Operations:
    - Copy: Use the `Copy` option in the context menu for quick file duplication.
    - Rename: Select `Rename` and specify the new name.
    - Delete: Use `Delete` to move the file to the trash.
3. Automatic Updates: The application will periodically scan the specified directories and refresh content in real time.



---
## Authors

- Iakov Senatov:  [![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

| Step                | Description                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| Installation        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| Running the Project | Use the command `swift run` to launch the project.                                             |
| Usage               | Access features like configuration, file management, network, and tools from the main menu.    |





---
## FAQ

| Question                             | Answer                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------- |
| How to configure settings?           | Navigate to Configuration to access display, layout, and color settings.  |
| How to compare directories?          | Use the Files menu to compare and sync directories.                       |
| Can I rename multiple files at once? | Yes, use the Multi-Rename Tool available under Tools.                     |
| Is FTP supported?                    | Yes, FTP connection tools are available under the Network menu.           |
| Clean the Project from artefacts     | periphery scan --config .periphery.yml                                    |



---
## Recent Changes
```sh
* 8e6a5a0 - Senatov  (HEAD -> master, origin/master, origin/feature-down-toolbar-2, origin/HEAD, feature-down-toolbar-2) save (4 minutes ago, 2025-11-20 17:25:45 +0100)
* a4cd29a - Senatov  conditional stage save (6 minutes ago, 2025-11-20 17:24:11 +0100)
* 958fe8d - Senatov  Fix: panels on main view (4 days ago, 2025-11-16 22:49:41 +0100)
* 493f9d2 - Senatov  fix: tab header (4 days ago, 2025-11-16 22:45:28 +0100)
* b8c096f - Senatov  3 panel: under construction (6 days ago, 2025-11-15 00:27:00 +0100)
* f2a5add - Senatov  refactor *Split* (6 days ago, 2025-11-14 17:00:25 +0100)
* dc72773 - Senatov  fix: down toolbar & split refactor (7 days ago, 2025-11-14 00:36:40 +0100)
* e75bc8f - Senatov  new class refactoring (7 days ago, 2025-11-14 00:23:11 +0100)
* 4361879 - Senatov  na also (7 days ago, 2025-11-13 20:55:33 +0100)
* d741cfc - Senatov  hueta (8 days ago, 2025-11-13 01:04:34 +0100)
* 0b02ce5 - Senatov  new prj configs and new formatted sources (8 days ago, 2025-11-13 00:44:49 +0100)
* ad0125e - Senatov  struct (8 days ago, 2025-11-12 22:41:35 +0100)
* 085a426 - Senatov  command shell call (8 days ago, 2025-11-12 22:37:23 +0100)
* 8fcc8ff - Senatov  no more View just helper:  ConsoleCurrPath.open (8 days ago, 2025-11-12 20:09:07 +0100)
* 8da07ff - Senatov  NOT TESTED fix(ui): bottom toolbar visibility & layout restored, added LiquidGlass contrast + vibrant icons (9 days ago, 2025-11-11 22:23:41 +0100)
* 2469d80 - Senatov  ensure it never covers the bottom toolbar visually (9 days ago, 2025-11-11 18:49:08 +0100)
* 3c33a70 - Senatov  cleaned prj from obsoletes (9 days ago, 2025-11-11 14:01:29 +0100)
* f34489a - Senatov  fix3-6: drop some shit, Figma Styles (13 days ago, 2025-11-07 21:49:58 +0100)
* 1ea884f - Senatov  fix 2-3: Figma Style/macOS 26.1 (13 days ago, 2025-11-07 21:45:27 +0100)
* eefbd04 - Senatov  fix1 Figma Style macOS 26.1 (13 days ago, 2025-11-07 20:39:06 +0100)
* 4c99e82 - Senatov  refactor, UI-test -OK (13 days ago, 2025-11-07 15:56:43 +0100)
* 9a513c1 - Senatov  jump to 50% on Double Click on Divider (2 weeks ago, 2025-11-06 20:36:00 +0100)
* 094c19e - Senatov  err on panels divider = 54% on Start (2 weeks ago, 2025-11-06 19:49:51 +0100)
* b363863 - Senatov  clean & refactoring. Tested. ok (3 weeks ago, 2025-11-02 19:33:56 +0100)
* 628ca77 - Senatov  popup percentage booble-tooltip (3 weeks ago, 2025-11-01 03:19:08 +0100)
* 4c50c1c - Senatov  popup percentage booble-tooltip (3 weeks ago, 2025-11-01 03:19:08 +0100)
* a7923e8 - Senatov  щл (3 weeks ago, 2025-11-02 15:17:22 +0100)
* 922e02a - Senatov  (tag: from_01.11.2025) Stage 1. OK. (3 weeks ago, 2025-10-31 20:55:41 +0100)
* 4aa1520 - Senatov  ok. tested (3 weeks ago, 2025-10-31 20:43:14 +0100)
* 895c93c - Senatov  trottling DONE. tested ok (3 weeks ago, 2025-10-31 14:53:51 +0100)
*   c89deba - Senatov  merging (3 weeks ago, 2025-10-31 14:44:18 +0100)
|\  
| * 6e08dd8 - Senatov  temp: pre-rollback (3 weeks ago, 2025-10-31 14:14:47 +0100)
| * 441c2a3 - Senatov  rename TotalCommanderResizableView  to DuoFilePanelView (3 weeks ago, 2025-10-31 14:09:31 +0100)
| * 0a01186 - Senatov  fix4 (3 weeks ago, 2025-10-31 01:22:16 +0100)
| * a74d8f6 - Senatov  pre-build (3 weeks ago, 2025-10-30 20:10:49 +0100)
* | 1f383e1 - Senatov  temp: pre-rollback (3 weeks ago, 2025-10-30 19:46:10 +0100)
* | ca8bd18 - Senatov  (tag: tabbing-ok) rename on DuoFilePanelView (3 weeks ago, 2025-10-28 21:49:50 +0100)
* | 5885b9a - Senatov  merge (3 weeks ago, 2025-10-28 21:39:27 +0100)
|/  
* 2f3bf45 - Senatov  panel divider fixed. Test ok (3 weeks ago, 2025-10-28 21:05:10 +0100)

```
---
 ##  Related Links

- [(NOT READY YET, still under Development)](#not-ready-yet-still-under-development)
- [Overview](#overview)
  - [General structure](#general-structure)
  - [Important aspects](#important-aspects)
  - [Getting started](#getting-started)
  - [Learning pointers](#learning-pointers)
- [Current Stage](#current-stage)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Authors](#authors)
- [FAQ](#faq)
- [Recent Changes](#recent-changes)
- [Related Links](#related-links)
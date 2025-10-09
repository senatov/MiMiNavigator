
<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="Preview FrontEnd"
    title="Logo"
    style="max-width: 100%; height: auto; border: 2px; border-radius: 4px;" />
</div>

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

<div style="text-align: center;" >
  <img
    src="GUI/Docs/Preview.png"
    alt="Preview FrontEnd"
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
- Xcode 26.1 beta 


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
    periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator
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

| Question                             | Answer                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------ |
| How to configure settings?           | Navigate to Configuration to access display, layout, and color settings. |
| How to compare directories?          | Use the Files menu to compare and sync directories.                      |
| Can I rename multiple files at once? | Yes, use the Multi-Rename Tool available under Tools.                    |
| Is FTP supported?                    | Yes, FTP connection tools are available under the Network menu.          |
| Clean the Project from artefacts     | periphery scan --config .periphery.yml                                   |



---
## Recent Changes
```sh
 897352e - Senatov  (HEAD -> master, origin/master, origin/HEAD) Merge branch 'new_fix' (2 minutes ago, 2025-09-28 14:27:17 +0200)
|\  
| * aff10ad - Senatov  (new_fix) Tab not works, up/down works so-so. Shit! (8 minutes ago, 2025-09-28 14:22:08 +0200)
| | * cbaf596 - Senatov  (refs/stash) On master: just repair prj func. bugs (3 minutes ago, 2025-09-28 14:26:45 +0200)
| |/| 
|/| | 
| | * 7a30f4c - Senatov  index on master: 07160d1 "selection" w. mouse & Tab on FilePanels (3 minutes ago, 2025-09-28 14:26:45 +0200)
| |/  
|/|   
* | 07160d1 - Senatov  "selection" w. mouse & Tab on FilePanels (4 days ago, 2025-09-24 17:05:36 +0200)
|/  
* 1c8a5de - Senatov  paths navigation / panel change (5 days ago, 2025-09-23 20:45:13 +0200)
* b1c5d72 - Senatov  optimize it (5 days ago, 2025-09-23 10:50:58 +0200)
* eeafe2b - Senatov  optimize (5 days ago, 2025-09-23 10:47:13 +0200)
* c2271b8 - Senatov  (tag: invisible) tmp (5 days ago, 2025-09-23 03:21:20 +0200)
* fab9596 - Senatov  (tag: should-deleted) tmp (9 days ago, 2025-09-19 13:48:33 +0200)
* 1c60432 - Senatov  yellow select balks (10 days ago, 2025-09-18 20:59:59 +0200)
* 2cacf0e - Senatov  insert appState & refactoring (10 days ago, 2025-09-18 04:32:13 +0200)
* 00ddfff - Senatov  colors Names (11 days ago, 2025-09-17 16:10:23 +0200)
* 79b2be5 - Senatov  fix prj config and leading bei breadcrump (2 weeks ago, 2025-09-13 02:54:11 +0200)
* f8d3e03 - Senatov  Tab Panel Selection (3 weeks ago, 2025-09-11 02:23:50 +0200)
* 1b4b13c - Senatov  fileprivate -> private (3 weeks ago, 2025-09-11 01:43:29 +0200)
* 709d5d2 - Senatov  replace log.debug( -> .info( (3 weeks ago, 2025-09-11 00:30:27 +0200)
* f3a9b85 - Senatov  console applescript (3 weeks ago, 2025-09-04 20:39:47 +0200)
* ce0f94d - Senatov  fix crumbs selections (3 weeks ago, 2025-09-04 14:30:51 +0200)
* 6d92e45 - Senatov  breadCrumb triangle fix (4 weeks ago, 2025-09-04 00:38:36 +0200)
* 2df3694 - Senatov  file + dir list sorting.ready! (4 weeks ago, 2025-08-30 23:31:53 +0200)
* d91e3a8 - Senatov  select colors, select frame fixed again (4 weeks ago, 2025-08-29 00:02:31 +0200)
* 693d44b - Senatov  temp save (5 weeks ago, 2025-08-27 02:38:22 +0200)
* 67b1459 - Senatov  sorting dir+links+files - yet wrong (5 weeks ago, 2025-08-26 19:05:46 +0200)
* 2658f03 - Senatov  colors fixed (5 weeks ago, 2025-08-26 18:19:34 +0200)
* f5b4cbb - Senatov  fix color (5 weeks ago, 2025-08-26 02:10:34 +0200)
* 5e69380 - Senatov  breadCrumps fix (5 weeks ago, 2025-08-26 00:37:02 +0200)
* 9a9ce4b - Senatov  prepare to next stage (5 weeks ago, 2025-08-25 12:36:04 +0200)
* b00ce71 - Senatov  sorting, headline, zebra, fix-fix (5 weeks ago, 2025-08-22 23:01:32 +0200)
* 37965e3 - Senatov  save temporarily (5 weeks ago, 2025-08-22 15:20:26 +0200)
* 93c8d12 - Senatov  save temporarily / buffer (5 weeks ago, 2025-08-22 15:12:03 +0200)
* cb19ebd - Senatov  move selection on file panels. Under work (6 weeks ago, 2025-08-14 03:06:31 +0200)
* a6c6221 - Senatov  .cannot select right ! (7 weeks ago, 2025-08-13 21:11:54 +0200)
* a8f3f2a - Senatov  .fix selection (7 weeks ago, 2025-08-13 20:40:50 +0200)
* c1e4350 - Senatov  fix logs + refactoring (7 weeks ago, 2025-08-13 16:25:03 +0200)
* 64732f0 - Senatov  versioning (7 weeks ago, 2025-08-12 03:33:06 +0200)
* 11cd09f - Senatov  screenshot new (7 weeks ago, 2025-08-12 03:15:57 +0200)
* 5551c06 - Senatov  new time stamp (7 weeks ago, 2025-08-12 03:11:40 +0200)
* cf85e07 - Senatov  time marker (7 weeks ago, 2025-08-12 03:09:36 +0200)
* 315006c - Senatov  fix select file style (7 weeks ago, 2025-08-12 03:01:36 +0200)
* 2bd2ca4 - Senatov  Update README.md (7 weeks ago, 2025-08-11 17:25:06 +0200)
* 0275db5 - Senatov  fix security attr. (7 weeks ago, 2025-08-11 17:21:58 +0200)
* b0142f5 - Senatov  add some features (7 weeks ago, 2025-08-11 16:15:15 +0200)
* ffc2de3 - Senatov  save prev (7 weeks ago, 2025-08-11 12:45:01 +0200)
* 914a1be - Senatov  fix save/loas user's preferences (7 weeks ago, 2025-08-10 22:57:37 +0200)
* 974d90e - Senatov  clean on 'periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator' (7 weeks ago, 2025-08-10 22:35:36 +0200)
* ac0c4bb - Senatov  fix String (7 weeks ago, 2025-08-10 22:14:13 +0200)
* 7e6c73b - Senatov  remove obsolete configs (7 weeks ago, 2025-08-10 19:52:23 +0200)
* ee66113 - Senatov  Update README.md (7 weeks ago, 2025-08-07 12:15:07 +0200)
* a24a585 - Senatov  remove Derived/ (7 weeks ago, 2025-08-07 12:10:58 +0200)
* 24d85b2 - Senatov  Update .gitignore (7 weeks ago, 2025-08-07 12:09:01 +0200)
* 1756bd0 - Senatov  preview & logo fixed (7 weeks ago, 2025-08-07 12:05:28 +0200)
* 626f362 - Senatov  preview & logo fixed (7 weeks ago, 2025-08-07 11:59:42 +0200)

```
q


---
 ##  Related Links

- [(NOT READY YET, still under Development)](#not-ready-yet-under-development----)
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


<div style="text-align: center;">
  <img 
    src="Gui/Assets.xcassets/AppIcon.appiconset/120.png" 
    alt="Preview FrontEnd" 
    title="Logo" 
    style="max-width: 100%; height: auto; border: 1px solid #87CEFA; border-radius: 4px;" />
</div>

---
### MiMiNavigator - MacOS File manager with two panels
## (NOT READY YET, under development    )



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

<div style="text-align: center;">
  <img 
    src="Gui/Docs/Preview.png" 
    alt="Preview FrontEnd" 
    title="Preview" 
    style="max-width: 100%; height: auto; border: 1px solid #87CEFA; border-radius: 4px;" />
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


Other resources include asset catalogs, entitlements files, and a `refreshVersionFile.zsh` script that updates the `.version` string.


---
### Important aspects

- **Concurrency** Directory scanning and file updates are handled by actors (`DualDirectoryScanner`, `FileSingleton`) and async tasks to keep the UI responsive.

- **User preferences** Window sizes, panel widths, and other state are stored using `UserPreferences`(UserDefaults wrappers).

- **Logging** `LogMan` sets up SwiftyBeaver console and file logging with custom icons for log levels.

- **Customization** Many UI components (menu buttons, path control, tooltip) are implemented as reusable SwiftUI views.

---
### Getting started

1. Clone the repository and open `MiMiNavigator.xcodeproj` in Xcode.

2. Build and run. The README outlines basic installation steps and features such as dual panel navigation and periodic directory scanning.

3. The main entry point is `MiMiNavigatorApp` which initializes logging and sets up the main view hierarchy. Explore `AppState` and `DualDirectoryScanner` to understand how directory changes propagate to the UI.

---
### Learning pointers

- **SwiftUI layout and modifiers** Many views use custom modifiers and gestures (e.g., `onHover`, drag gestures for the divider).

- **Actors and concurrency** `DualDirectoryScanner` demonstrates using timers inside an actor for periodic work.

- **AppKit interop** Some components rely on `NSWorkspace`, `NSAlert`, and other AppKit APIs for macOS 6.4 specific functionality.

- **Persistent data** The app uses SwiftData `ModelContainer` for future persistence, though currently the `Item`model is minimal.


This project is still under active development ( NOT READY YET  per the README) but provides a clear example of a SwiftUI macOS application with multithreading, logging, and modular UI components.

---
## Current Stage

-  Support for macOS 26 with Swift 6.2 beta.
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
- Xcode 26.0 beta or later (recommended version: 26) *


---
##  Installation

1. Clone the repository:
    ```szh
    git clone https://github.com/username/MiMiNavigator.git
    cd MiMiNavigator
    ```
2. Open the project in Xcode:
    ```szh
    open MiMiNavigator.xcodeproj
    ```
3. Build and Run through Xcode or with the command:
    ```szh
    xcodebuild -scheme MiMiNavigator -sdk macosx
    ```
4. Check sources
    ```szh
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
|---------------------|------------------------------------------------------------------------------------------------|
| Installation        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| Running the Project | Use the command `swift run` to launch the project.                                             |
| Usage               | Access features like configuration, file management, network, and tools from the main menu.    |





---
## FAQ

| Question                                 | Answer                                                               |
|------------------------------------------|----------------------------------------------------------------------|
| How to configure settings?           | Navigate to Configuration to access display, layout, and color settings. |
| How to compare directories?          | Use the Files menu to compare and sync directories.                      |
| Can I rename multiple files at once? | Yes, use the Multi-Rename Tool available under Tools.                    |
| Is FTP supported?                    | Yes, FTP connection tools are available under the Network menu.          |
| Clean the Project                    | periphery scan --config .periphery.yml                                   |



---
## Recent Changes
```text
* a24a585 - Senatov  (HEAD -> master, origin/master, origin/HEAD) remove Derived/ (71 seconds ago, 2025-08-07 12:10:58 +0200)
* 24d85b2 - Senatov  Update .gitignore (3 minutes ago, 2025-08-07 12:09:01 +0200)
* 1756bd0 - Senatov  preview & logo fixed (7 minutes ago, 2025-08-07 12:05:28 +0200)
* 626f362 - Senatov  (origin/new_prj_structure, new_prj_structure) preview & logo fixed (12 minutes ago, 2025-08-07 11:59:42 +0200)
* 891e539 - Senatov  Update README.md (25 minutes ago, 2025-08-07 11:47:26 +0200)
* fee99fa - Senatov  preview & logo fixed (15 minutes ago, 2025-08-07 11:57:01 +0200)
* 1bfdc29 - Senatov  Update README.md (19 minutes ago, 2025-08-07 11:52:46 +0200)
* 7cc55a4 - Senatov  Update README.md (21 minutes ago, 2025-08-07 11:50:52 +0200)
* c9c4b6a - Senatov  Update README.md (23 minutes ago, 2025-08-07 11:49:03 +0200)
* a654aef - Senatov  Update README.md (25 minutes ago, 2025-08-07 11:47:26 +0200)
* 4b29a36 - Senatov  fix paths (30 minutes ago, 2025-08-07 11:42:32 +0200)
* 29c4690 - Senatov  some fixies (39 minutes ago, 2025-08-07 11:33:08 +0200)
* 06d8906 - Senatov  new project structure (67 minutes ago, 2025-08-07 11:05:07 +0200)
* 7e33650 - Senatov  new project structure (67 minutes ago, 2025-08-07 11:04:59 +0200)
* 8829a33 - Senatov  .error fixing (10 hours ago, 2025-08-07 02:28:55 +0200)
* 4ddde6d - Senatov  the same (2 days ago, 2025-08-05 11:09:49 +0200)
* 7e8615a - Senatov  fix file selection balk (2 days ago, 2025-08-05 10:26:31 +0200)
| * c7e1636 - Senatov  (2025.08.02-1) tmp (5 days ago, 2025-08-02 01:27:17 +0200)
|/  
* 519ee90 - Senatov  impl select history I (7 days ago, 2025-07-31 19:00:54 +0200)
* 6ccbde8 - Senatov  click on breadCrump - fixed (9 days ago, 2025-07-29 02:17:52 +0200)
* db3def8 - Senatov  update md (10 days ago, 2025-07-29 00:40:30 +0200)
* 1b7cc0a - Senatov  fix: recursion on path - on works (13 days ago, 2025-07-25 19:11:58 +0200)
* a433406 - Senatov  fixies: ver new (13 days ago, 2025-07-25 00:49:28 +0200)
* d2808d8 - Senatov  fixies: -- (13 days ago, 2025-07-25 00:46:37 +0200)
* 46b9ac5 - Senatov  fixies: next (13 days ago, 2025-07-25 00:42:55 +0200)
* 7564737 - Senatov  fixed AppState (2 weeks ago, 2025-07-24 17:24:23 +0200)
* 4614581 - Senatov  fixies: between (2 weeks ago, 2025-07-24 03:27:12 +0200)
* f5fe17f - Senatov  selectedSide next fixies (2 weeks ago, 2025-07-22 12:26:36 +0200)
* 4bd8706 - Senatov  path in panel and und crumb synchronised (2 weeks ago, 2025-07-22 12:03:37 +0200)
* 080c288 - Senatov  ver (2 weeks ago, 2025-07-22 09:54:04 +0200)
* bb0e963 - Senatov  shadows fixed (2 weeks ago, 2025-07-22 09:53:53 +0200)
* 9bcb6cd - Senatov  .new preview (2 weeks ago, 2025-07-21 23:52:16 +0200)
* 7cc4117 - Senatov  .ver (2 weeks ago, 2025-07-21 23:48:50 +0200)
* c132de5 - Senatov  .fix sides (not ready) (2 weeks ago, 2025-07-21 23:48:15 +0200)
* 781bbe6 - Senatov  .right & .left repaired. ok (2 weeks ago, 2025-07-21 17:29:53 +0200)
* 3087ed4 - Senatov  search on Error left an right (2 weeks ago, 2025-07-21 17:07:29 +0200)
* 6c5ed55 - Senatov  PrettyTooltip (2 weeks ago, 2025-07-21 13:41:22 +0200)
* 89a0d53 - Senatov  stage saved (2 weeks ago, 2025-07-21 01:08:37 +0200)
* d32baa8 - Senatov  clean after scan --project MiMiNavigator (3 weeks ago, 2025-07-20 19:12:34 +0200)
* f7d4092 - Senatov  EditablePathControlWrapper(selectedSide: currSide) / remove @Environment (3 weeks ago, 2025-07-20 12:18:13 +0200)
* 2e6e19a - Senatov  after periphery scan (3 weeks ago, 2025-07-20 01:09:55 +0200)
* 06c6dd5 - Senatov  after "periphery scan" (3 weeks ago, 2025-07-19 23:57:15 +0200)
* 1f8f445 - Senatov  .initial (3 weeks ago, 2025-07-19 23:22:00 +0200)
*   c9e7e6d - Senatov  Merge branch 'refs/heads/fix_errors' (3 weeks ago, 2025-07-18 09:01:46 +0200)
|\  
| * 7e63b4c - Senatov  fixed (3 weeks ago, 2025-07-18 06:45:53 +0200)
* | 787827d - Senatov  +wrong (3 weeks ago, 2025-07-18 06:10:28 +0200)
* | 2de1fd8 - Senatov  tmp wrong (3 weeks ago, 2025-07-18 05:49:31 +0200)
* | 8674f2d - Senatov  not ready (3 weeks ago, 2025-07-17 21:51:25 +0200)
* | 29713d3 - Senatov  button fav directories (3 weeks ago, 2025-07-17 19:50:46 +0200)
|/  
* e1b6b00 - Senatov  top favorites mnu popup - not ready yet (3 weeks ago, 2025-07-17 19:46:43 +0200)
* 53b6dc9 - Senatov  dirs&linkeddir&files color (default after clean install) (3 weeks ago, 2025-07-17 11:47:09 +0200)
* 948d4b0 - Senatov  in utf8 (3 weeks ago, 2025-07-17 01:32:19 +0200)
* 2dad0c4 - Senatov  .merged (3 weeks ago, 2025-07-17 01:28:49 +0200)
*   142a08f - Senatov  Merge remote-tracking branch 'origin/master' (3 weeks ago, 2025-07-17 01:25:37 +0200)
|\  
| * 44752c2 - Senatov  Update README.md (3 weeks ago, 2025-07-17 00:50:23 +0200)

```



---
 ##  Related Links

- [(NOT READY YET, under development    )](#not-ready-yet-under-development----)
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

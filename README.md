![MiMiNavigator Logo](MiMiNavigator/Assets.xcassets/AppIcon.appiconset/256%201.png "just logo")

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



##     Overview
MiMiNavigator is a macOS file manager built with Swift and SwiftUI.
The repository is organized around an Xcode project with sources under `MiMiNavigator/` and basic tests in `MiMiNavigatorTests` and `MiMiNavigatorUITests`.

<p align="center">
  <img src="docs/Preview.png" alt="Preview FrontEnd" title="Preview" style="max-width: 100%; height: auto;" />
</p>


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

### Important aspects

- **Concurrency** Directory scanning and file updates are handled by actors (`DualDirectoryScanner`, `FileSingleton`) and async tasks to keep the UI responsive.

- **User preferences** Window sizes, panel widths, and other state are stored using `UserPreferences`(UserDefaults wrappers).

- **Logging** `LogMan` sets up SwiftyBeaver console and file logging with custom icons for log levels.

- **Customization** Many UI components (menu buttons, path control, tooltip) are implemented as reusable SwiftUI views.


### Getting started

1. Clone the repository and open `MiMiNavigator.xcodeproj` in Xcode.

2. Build and run. The README outlines basic installation steps and features such as dual panel navigation and periodic directory scanning.

3. The main entry point is `MiMiNavigatorApp` which initializes logging and sets up the main view hierarchy. Explore `AppState` and `DualDirectoryScanner` to understand how directory changes propagate to the UI.


### Learning pointers

- **SwiftUI layout and modifiers** Many views use custom modifiers and gestures (e.g., `onHover`, drag gestures for the divider).

- **Actors and concurrency** `DualDirectoryScanner` demonstrates using timers inside an actor for periodic work.

- **AppKit interop** Some components rely on `NSWorkspace`, `NSAlert`, and other AppKit APIs for macOS 6.4 specific functionality.

- **Persistent data** The app uses SwiftData `ModelContainer` for future persistence, though currently the `Item`model is minimal.


This project is still under active development ( NOT READY YET  per the README) but provides a clear example of a SwiftUI macOS application with multithreading, logging, and modular UI components.


## Current Stage

-  Support for macOS 26 with Swift 6.2 beta.
-  Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
-  Modular and reusable components for top navigation.
-  Integrated file management actions including copy, rename, and delete.
-  Full Total Commander submenu structure recreated.
-  Dynamic output naming in shell utilities.
-  Dual-panel interface for managing files and directories.
-  Automatic UI updates when directory contents change.

## Requirements

- macOS 26 or later
- Swift 6.2
- Xcode 26.0 beta or later (recommended version: 26) *


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

 ## Usage

1. Launching: Open the application and set directories for dual-panel mode.
2. File Operations:
    - Copy: Use the `Copy` option in the context menu for quick file duplication.
    - Rename: Select `Rename` and specify the new name.
    - Delete: Use `Delete` to move the file to the trash.
3. Automatic Updates: The application will periodically scan the specified directories and refresh content in real time.

## Authors

- Iakov Senatov:  [![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

| Step           | Description                                                                                         |
|-------------------------|--------------------------------------------------------------------------------------------|
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
```log
 53b6dc9 - Senatov  dirs&linkeddir&files color (default after clean install) (8 hours ago, 2025-07-17 11:47:09 +0200)
* 948d4b0 - Senatov  in utf8 (18 hours ago, 2025-07-17 01:32:19 +0200)
* 2dad0c4 - Senatov  .merged (18 hours ago, 2025-07-17 01:28:49 +0200)
*   142a08f - Senatov  Merge remote-tracking branch 'origin/master' (18 hours ago, 2025-07-17 01:25:37 +0200)
|\  
| * 44752c2 - Senatov  Update README.md (19 hours ago, 2025-07-17 00:50:23 +0200)
| * c3f2abd - Senatov  Update README.md (19 hours ago, 2025-07-17 00:48:26 +0200)
* | 5cbad92 - Senatov  ver. and md fix (18 hours ago, 2025-07-17 01:24:19 +0200)
* | b452414 - Senatov  fix preview (19 hours ago, 2025-07-17 01:09:11 +0200)
|/  
* 443b60c - Senatov  fixed: intern size of panels and side var (19 hours ago, 2025-07-17 00:46:17 +0200)
* c0d76df - Senatov  test (21 hours ago, 2025-07-16 23:19:11 +0200)
* 6abe2a4 - Senatov  restore preview (21 hours ago, 2025-07-16 22:35:08 +0200)
* ebf3a9c - Senatov  file pane's headers (21 hours ago, 2025-07-16 22:28:12 +0200)
* a9c3fd8 - Senatov  .@concurrent (24 hours ago, 2025-07-16 19:34:12 +0200)
* 6cef802 - Senatov  down button panel paddind (27 hours ago, 2025-07-16 16:54:20 +0200)
* 2d99e1a - Senatov  ver. string (29 hours ago, 2025-07-16 15:06:25 +0200)
* 14c7dc4 - Senatov  nothing intresting (29 hours ago, 2025-07-16 14:43:24 +0200)
* 5ce7f3a - Senatov  current (30 hours ago, 2025-07-16 14:13:44 +0200)
* 2cb4f03 - Senatov  Update README.md (3 weeks ago, 2025-06-28 18:09:38 +0200)
* b8ef797 - Senatov  pnl new look (3 weeks ago, 2025-06-28 14:24:36 +0200)
* 61e9c2e - Senatov  panel's new look (3 weeks ago, 2025-06-28 14:24:01 +0200)
* d8ab337 - Senatov  + new look buildPanel (left & rihgt) (3 weeks ago, 2025-06-28 13:27:00 +0200)
* 4bc8408 - Senatov  + event-catch / logging (3 weeks ago, 2025-06-28 10:18:49 +0200)
* 6a52d07 - Senatov  logging chng (3 weeks ago, 2025-06-26 00:52:15 +0200)
* 2936041 - Senatov  fileManager.urls(...) - as initial (3 weeks ago, 2025-06-25 20:53:54 +0200)
* f2b95cf - Senatov  print -> log.debug (3 weeks ago, 2025-06-25 20:44:07 +0200)
* 837e0d5 - Senatov  reconf +State package (3 weeks ago, 2025-06-25 05:40:32 +0200)
* c9003df - Senatov  Simplify the App code (3 weeks ago, 2025-06-24 17:45:47 +0200)
* 2bccace - Senatov  хуета какая-то, ошибки (3 weeks ago, 2025-06-24 07:10:34 +0200)
* 2692c53 - Senatov  fixed. (4 weeks ago, 2025-06-22 19:38:32 +0200)
* 88090e4 - Senatov  fix-small (4 weeks ago, 2025-06-21 18:33:40 +0200)
* cae036b - Senatov  update log (4 weeks ago, 2025-06-21 15:55:02 +0200)
* 5702a51 - Senatov  update log (4 weeks ago, 2025-06-21 15:54:52 +0200)
* b820879 - Senatov  .between (4 weeks ago, 2025-06-20 03:14:05 +0200)
* 49beeb9 - Senatov  (origin/2025.13, 2025.13) dir. scanner params (4 weeks ago, 2025-06-18 21:35:00 +0200)
* 9217548 - Senatov  cosmetic (4 weeks ago, 2025-06-18 20:54:04 +0200)
* 20ab256 - Senatov  new logos (4 weeks ago, 2025-06-17 02:03:51 +0200)
* 5bdf655 - Senatov  new ver. string (4 weeks ago, 2025-06-16 22:32:37 +0200)
* d6b78fe - Senatov  smi (4 weeks ago, 2025-06-16 22:30:52 +0200)
* 38b0532 - Senatov  clean app. Check left and right (4 weeks ago, 2025-06-16 19:44:02 +0200)
* ee1a5d9 - Senatov  (tag: preview) new ver marker (5 weeks ago, 2025-06-11 12:53:43 +0200)
*   6db49aa - Senatov  Merge remote-tracking branch 'origin/detached' (5 weeks ago, 2025-06-11 12:51:31 +0200)
|\  
| * c5f7ef5 - Senatov  (origin/detached) tested. global vars implemented. (7 weeks ago, 2025-05-31 14:58:44 +0200)
| * 3eef2c3 - Senatov  call refresh files cngs (7 weeks ago, 2025-05-31 00:55:49 +0200)
* | 0d75775 - Senatov  new look (5 weeks ago, 2025-06-11 12:46:46 +0200)
* | 71342ab - Senatov  new look (5 weeks ago, 2025-06-11 12:45:19 +0200)
* | 850a462 - Senatov  convert to XCode 26. OK (5 weeks ago, 2025-06-11 00:34:10 +0200)
* | 4a480ba - Senatov  to XCode ver. 26 (5 weeks ago, 2025-06-10 23:37:38 +0200)
* | 18dadff - Senatov  added ndo (5 weeks ago, 2025-06-10 13:06:39 +0200)
* | dcb4f32 - Senatov  min. fix of calls. Tested. Memory leaks (7 weeks ago, 2025-06-01 20:29:01 +0200)
* | 89dcabb - Senatov      timeOutRefresh (7 weeks ago, 2025-06-01 19:50:24 +0200)
* | 806f3fe - Senatov  Top Mnu categories as @MainActor (7 weeks ago, 2025-06-01 14:02:23 +0200)
* | 19ea964 - Senatov  button "Help" + placeholders (7 weeks ago, 2025-06-01 13:46:57 +0200)
* | 3771099 - Senatov  refresh info (7 weeks ago, 2025-06-01 12:29:52 +0200)
* | 6b453d5 - Senatov  version status info (7 weeks ago, 2025-06-01 10:53:02 +0200)
* | fc0fc7c - Senatov  scann repair (7 weeks ago, 2025-06-01 10:50:53 +0200)
```

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

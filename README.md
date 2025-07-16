![MiMiNavigator Logo](MiMiNavigator/Assets.xcassets/AppIcon.appiconset/128.png "MiMi Logo")


# 📁 MiMiNavigator - MacOS File manager with two panels
### (NOT READY YET, under development 🧹)

##

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

![Preview](MiMiNavigator/Docs/Preview.png "Programm preview")

## 📖 Overview
MiMiNavigator is a macOS file manager built with Swift and SwiftUI.  
The repository is organized around an Xcode project with sources under `MiMiNavigator/` and basic tests in `MiMiNavigatorTests` and `MiMiNavigatorUITests`.

### General structure

Key directories inside `MiMiNavigator/`:

- **App** – entry point and logging setup. The application reads a `.version` file, sets up a shared model container, and displays a main split‑view UI with a log viewer button. The code uses SwiftyBeaver for logging.
    
- **States** – observable classes and actors that hold runtime state. `AppState` tracks the current directories and selected files, while `DualDirectoryScanner` scans both panels using timers and async updates.
    
- **Models** – data structures such as `CustomFile`, an entity representing files or directories, and `FileSingleton`, an actor maintaining left/right file lists for SwiftUI updates.
    
- **Views** – SwiftUI views for file panels, the top menu bar, and toolbar. `TotalCommanderResizableView` composes the main UI with a draggable divider and toolbar buttons for actions like view, edit, copy, and delete.
    
- **BreadCrumbNav** – editable path controls and breadcrumb navigation.
    
- **Favorite** – scans frequently used directories and mounted volumes to show a favorites tree.
    
- **Menus** – menu item models and top menu rendering.
    

Other resources include asset catalogs, entitlements files, and a `refreshVersionFile.zsh` script that updates the `.version` string.

### Important aspects

- **Concurrency** – Directory scanning and file updates are handled by actors (`DualDirectoryScanner`, `FileSingleton`) and async tasks to keep the UI responsive.
    
- **User preferences** – Window sizes, panel widths, and other state are stored using `UserPreferences`(UserDefaults wrappers).
    
- **Logging** – `LogMan` sets up SwiftyBeaver console and file logging with custom icons for log levels.
    
- **Customization** – Many UI components (menu buttons, path control, tooltip) are implemented as reusable SwiftUI views.
    

### Getting started

1. Clone the repository and open `MiMiNavigator.xcodeproj` in Xcode.
    
2. Build and run. The README outlines basic installation steps and features such as dual‑panel navigation and periodic directory scanning.
    
3. The main entry point is `MiMiNavigatorApp` which initializes logging and sets up the main view hierarchy. Explore `AppState` and `DualDirectoryScanner` to understand how directory changes propagate to the UI.
    

### Learning pointers

- **SwiftUI layout and modifiers** – Many views use custom modifiers and gestures (e.g., `onHover`, drag gestures for the divider).
    
- **Actors and concurrency** – `DualDirectoryScanner` demonstrates using timers inside an actor for periodic work.
    
- **AppKit interop** – Some components rely on `NSWorkspace`, `NSAlert`, and other AppKit APIs for macOS‑specific functionality.
    
- **Persistent data** – The app uses SwiftData `ModelContainer` for future persistence, though currently the `Item`model is minimal.
    

This project is still under active development (“NOT READY YET” per the README) but provides a clear example of a SwiftUI macOS application with multithreading, logging, and modular UI components.



# ✨ Features (NOT READY YET, under development 🧹)

## Current Stage 🦾 

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


## 🚀 Installation

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

## 📋 Usage

1. Launching: Open the application and set directories for dual-panel mode.
2. File Operations:
    - Copy: Use the `Copy` option in the context menu for quick file duplication.
    - Rename: Select `Rename` and specify the new name.
    - Delete: Use `Delete` to move the file to the trash.
3. Automatic Updates: The application will periodically scan the specified directories and refresh content in real time.

## 👤 Authors
- Iakov Senatov:  [![LinkedIn](https://www.shareicon.net/data/128x128/2017/06/16/887138_logo_512x512.png?logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

| Step           | Description                                                                                         |
|-------------------------|--------------------------------------------------------------------------------------------|
| Installation        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| Running the Project | Use the command `swift run` to launch the project.                                             |
| Usage               | Access features like configuration, file management, network, and tools from the main menu.    |

---




##❓FAQ❓ 

| Question                                 | Answer                                                               |
|------------------------------------------|----------------------------------------------------------------------|
| How to configure settings?           | Navigate to Configuration to access display, layout, and color settings. |
| How to compare directories?          | Use the Files menu to compare and sync directories.                      |
| Can I rename multiple files at once? | Yes, use the Multi-Rename Tool available under Tools.                    |
| Is FTP supported?                    | Yes, FTP connection tools are available under the Network menu.          |
| Clean the Project                    | periphery scan --config .periphery.yml                                   |

---



## 📅 Recent Changes
```log
* b820879 - Senatov  (HEAD -> master) .between (2 days ago, 2025-06-20 03:14:05 +0200)
* 49beeb9 - Senatov  (origin/master, origin/HEAD, origin/2025.13, 2025.13) dir. scanner params (3 days ago, 2025-06-18 21:35:00 +0200)
* 9217548 - Senatov  cosmetic (3 days ago, 2025-06-18 20:54:04 +0200)
* 20ab256 - Senatov  new logos (5 days ago, 2025-06-17 02:03:51 +0200)
* 5bdf655 - Senatov  new ver. string (5 days ago, 2025-06-16 22:32:37 +0200)
* d6b78fe - Senatov  smi (5 days ago, 2025-06-16 22:30:52 +0200)
* 38b0532 - Senatov  clean app. Check left and right (5 days ago, 2025-06-16 19:44:02 +0200)
* ee1a5d9 - Senatov  (tag: preview) new ver marker (10 days ago, 2025-06-11 12:53:43 +0200)
*   6db49aa - Senatov  Merge remote-tracking branch 'origin/detached' (10 days ago, 2025-06-11 12:51:31 +0200)
|\  
| * c5f7ef5 - Senatov  (origin/detached) tested. global vars implemented. (3 weeks ago, 2025-05-31 14:58:44 +0200)
| * 3eef2c3 - Senatov  call refresh files cngs (3 weeks ago, 2025-05-31 00:55:49 +0200)
* | 0d75775 - Senatov  new look (10 days ago, 2025-06-11 12:46:46 +0200)
* | 71342ab - Senatov  new look (10 days ago, 2025-06-11 12:45:19 +0200)
* | 850a462 - Senatov  convert to XCode 26. OK (11 days ago, 2025-06-11 00:34:10 +0200)
* | 4a480ba - Senatov  to XCode ver. 26 (11 days ago, 2025-06-10 23:37:38 +0200)
* | 18dadff - Senatov  added ndo (11 days ago, 2025-06-10 13:06:39 +0200)
* | dcb4f32 - Senatov  min. fix of calls. Tested. Memory leaks (3 weeks ago, 2025-06-01 20:29:01 +0200)
* | 89dcabb - Senatov      timeOutRefresh (3 weeks ago, 2025-06-01 19:50:24 +0200)
* | 806f3fe - Senatov  Top Mnu categories as @MainActor (3 weeks ago, 2025-06-01 14:02:23 +0200)
* | 19ea964 - Senatov  button "Help" + placeholders (3 weeks ago, 2025-06-01 13:46:57 +0200)
* | 3771099 - Senatov  refresh info (3 weeks ago, 2025-06-01 12:29:52 +0200)
* | 6b453d5 - Senatov  version status info (3 weeks ago, 2025-06-01 10:53:02 +0200)
* | fc0fc7c - Senatov  scann repair (3 weeks ago, 2025-06-01 10:50:53 +0200)
* | 10ef616 - Senatov  clean 2 (3 weeks ago, 2025-05-31 17:20:45 +0200)
* | 7e6f932 - Senatov  clean 1 (3 weeks ago, 2025-05-31 16:35:55 +0200)
* | 64e57fa - Senatov  zombi git- branch repaired (3 weeks ago, 2025-05-31 16:10:22 +0200)
* | 4a67f7a - Senatov  Scanner n. works last 2 days (3 weeks ago, 2025-05-31 00:35:40 +0200)
* | f297d96 - Senatov  ok- хватит на сегодня, блеать (3 weeks ago, 2025-05-30 00:57:56 +0200)
* | b423474 - Senatov  down buttons func. (3 weeks ago, 2025-05-30 00:52:16 +0200)
* | 38dbfbd - Senatov  refactor. down & context menu (3 weeks ago, 2025-05-29 18:36:59 +0200)
* | 63c539d - Senatov  Breadcrumb design (3 weeks ago, 2025-05-29 18:30:25 +0200)
|/  
* 6a56378 - Senatov  .refresh (3 weeks ago, 2025-05-29 18:20:17 +0200)
* 88f82a6 - Senatov  errors fix. Compiled, starded, where are errs (3 weeks ago, 2025-05-29 18:19:30 +0200)
* 49e70a1 - Senatov  + .environmentObject(appState) (3 weeks ago, 2025-05-29 16:06:39 +0200)
* f7da70c - Senatov  cleaning, refactoring II (3 weeks ago, 2025-05-29 15:00:37 +0200)
* a21ab7c - Senatov  cleaning, refactorimg (3 weeks ago, 2025-05-28 23:33:22 +0200)
* 07d8a26 - Senatov  something .wrong (no fle list) (4 weeks ago, 2025-05-26 21:48:45 +0200)
* c8dbc28 - Senatov  small fixies (4 weeks ago, 2025-05-26 20:30:55 +0200)
* cdb3012 - Senatov  added (4 weeks ago, 2025-05-26 11:39:25 +0200)
* 6cf8c11 - Senatov  +folders (4 weeks ago, 2025-05-26 02:41:16 +0200)
* cf342ad - Senatov  + Folders Structure (4 weeks ago, 2025-05-26 02:40:46 +0200)
* b5053ae - Senatov  select initial dir /tmp (4 weeks ago, 2025-05-25 23:34:55 +0200)
* 02ede19 - Senatov  under work (4 weeks ago, 2025-05-24 14:59:33 +0200)
* 19f05bc - Senatov  fix everytwhere: @StateObject var selection = SelectedDir() (4 weeks ago, 2025-05-22 17:06:44 +0200)
* 596fa2c - Senatov  recomposition (4 weeks ago, 2025-05-22 01:41:19 +0200)
* 95c5598 - Senatov  fix-1 (4 weeks ago, 2025-05-22 01:36:49 +0200)
* 17c4ede - Senatov  UserDefaults save/restore (5 weeks ago, 2025-05-20 20:01:34 +0200)
* b1aae52 - Senatov          SelectedDir var everywhere (5 weeks ago, 2025-05-20 10:54:24 +0200)
* 6101772 - Senatov  aliases f. links (5 weeks ago, 2025-05-18 23:19:00 +0200)
* 33e9c9a - Senatov  selectedDir on click - 1 (5 weeks ago, 2025-05-18 15:04:02 +0200)
* 8fedb57 - Senatov  title w. version (5 weeks ago, 2025-05-18 13:12:09 +0200)
* 8e16013 - Senatov  BreadCrump Panel II (5 weeks ago, 2025-05-18 09:10:26 +0200)
* e4f22c0 - Senatov  BreadCrump fixed (wrong) (5 weeks ago, 2025-05-17 02:20:04 +0200)
* 0027bbe - Senatov  tested: 1)global FileStucture cnhg 2) Formatted 3) GUI (6 weeks ago, 2025-05-12 15:51:59 +0200)
* 2a0f44a - Senatov  on edit (err!) (6 weeks ago, 2025-05-10 17:13:37 +0200)
* ada8c88 - Senatov  on edit (6 weeks ago, 2025-05-10 17:13:14 +0200)
* 73c795e - Senatov  roung:7,  Sandbox: /Volumes sec dialog (6 weeks ago, 2025-05-08 15:53:16 +0200):
...
```

## 🔗 Related Links

- [Installation Guide](#quick-start-guide)
- [Features and Options](#features-and-options)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)

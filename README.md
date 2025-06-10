![MiMiNavigator Logo](MiMiNavigator/Assets.xcassets/AppIcon.appiconset/87.png "just logo")


# 📁 MiMiNavigator - MacOS File manager with two panels
### (NOT READY YET, under development 🧹)

##

[![Swift Version](https://img.shields.io/badge/Swift-6.4-blue.svg)](https://swift.org)
[![Xcode Version](https://img.shields.io/badge/Xcode-16.5-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Framework](https://img.shields.io/badge/Framework-SwiftUI-blueviolet.svg)](https://developer.apple.com/xcode/swiftui/)
[![Mac Studio](https://img.shields.io/badge/Device-Mac_Studio_M2Max-orange.svg)](https://www.apple.com/mac-studio/)
[![Memory](https://img.shields.io/badge/RAM-32_GB-brightgreen.svg)]()
[![Encryption](https://img.shields.io/badge/Encryption-Enabled-green.svg)]()
[![Programming](https://img.shields.io/badge/Type-Free_Programming-lightblue.svg)]()
[![Shareware](https://img.shields.io/badge/License-Freeware-yellow.svg)]()

## 📖 Overview
**MiMiNavigator** is a versatile navigation tool designed specifically for **macOS**. Built using **Swift** and **SwiftUI**, this project leverages the power of **Apple**'s ecosystem to provide a seamless experience. It includes advanced features that make full use of **multitasking** and **multithreading**, allowing efficient handling of directory monitoring, file operations, and user interactions.

This application highlights the strengths of **SwiftUI** in creating intuitive, responsive user interfaces and utilizes **multithreading** for efficient background processes, such as file scanning and updating views, ensuring that the application remains responsive even with intensive tasks.

**MiMiNavigator** is a versatile navigation tool that provides a Total Commander-style interface with directory tree navigation. This project is built with Swift 6, delivering high-performance, real-time file operations.




# ✨ Features (NOT READY YET, under development 🧹)

## Current Stage 🦾 ![Current Stage](docs/Preview.png "current preview")

-  Support for macOS 15.3 with Swift 6.2.
-  Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
-  Modular and reusable components for top navigation.
-  Integrated file management actions including copy, rename, and delete.
-  Full Total Commander submenu structure recreated.
-  Dynamic output naming in shell utilities.
-  Dual-panel interface for managing files and directories.
-  Automatic UI updates when directory contents change.

## Requirements

- **macOS** 15.4 or later
- **Swift** 6.3
- **Xcode** 16.3 or later (recommended version: 26) *
- **macOS** Sequoia 15.0 or later

## 🚀 Installation

1. **Clone the repository:**
    ```bash
    git clone https://github.com/username/MiMiNavigator.git
    cd MiMiNavigator
    ```
2. **Open the project in Xcode:**
    ```bash
    open MiMiNavigator.xcodeproj
    ```
3. **Build and Run** through Xcode or with the command:
    ```bash
    xcodebuild -scheme MiMiNavigator -sdk macosx
    ```
4. **Check sources** 
    ```bash
    periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator
    ```     

## 📋 Usage

1. **Launching**: Open the application and set directories for dual-panel mode.
2. **File Operations**:
    - **Copy**: Use the `Copy` option in the context menu for quick file duplication.
    - **Rename**: Select `Rename` and specify the new name.
    - **Delete**: Use `Delete` to move the file to the trash.
3. **Automatic Updates**: The application will periodically scan the specified directories and refresh content in real time.

## 👤 Authors

- Iakov Senatov:
  [![LinkedIn](https://img.shields.io/badge/LinkedIn-blue.svg?logo=linkedin&colorB=555)](https://www.linkedin.com/in/iakov-senatov-07060765)

| Step                    | Description                                                                                    |
|-------------------------|------------------------------------------------------------------------------------------------|
| **Installation**        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| **Running the Project** | Use the command `swift run` to launch the project.                                             |
| **Usage**               | Access features like configuration, file management, network, and tools from the main menu.    |

---




##❓FAQ❓ 

| Question                                 | Answer                                                                       |
|------------------------------------------|------------------------------------------------------------------------------|
| **How to configure settings?**           | Navigate to **Configuration** to access display, layout, and color settings. |
| **How to compare directories?**          | Use the **Files** menu to compare and sync directories.                      |
| **Can I rename multiple files at once?** | Yes, use the **Multi-Rename Tool** available under **Tools**.                |
| **Is FTP supported?**                    | Yes, FTP connection tools are available under the **Network** menu.          |
| **Clean the Project**                    | periphery scan --config .periphery.yml                                       |

---



## 📅 Recent Changes
```ansi
* 6b453d5 - Senatov  (HEAD -> master, origin/master, origin/HEAD) version status info (2 hours ago, 2025-06-01 10:53:02 +0200)
* fc0fc7c - Senatov  scann repair (2 hours ago, 2025-06-01 10:50:53 +0200)
* 10ef616 - Senatov  clean 2 (19 hours ago, 2025-05-31 17:20:45 +0200)
* 7e6f932 - Senatov  clean 1 (20 hours ago, 2025-05-31 16:35:55 +0200)
* 64e57fa - Senatov  zombi git- branch repaired (20 hours ago, 2025-05-31 16:10:22 +0200)
* 4a67f7a - Senatov  Scanner n. works last 2 days (2 days ago, 2025-05-31 00:35:40 +0200)
* f297d96 - Senatov  ok- хватит на сегодня, блеать (2 days ago, 2025-05-30 00:57:56 +0200)
* b423474 - Senatov  down buttons func. (3 days ago, 2025-05-30 00:52:16 +0200)
* 38dbfbd - Senatov  refactor. down & context menu (3 days ago, 2025-05-29 18:36:59 +0200)
* 63c539d - Senatov  Breadcrumb design (3 days ago, 2025-05-29 18:30:25 +0200)
| * c5f7ef5 - Senatov  (origin/detached) tested. global vars implemented. (21 hours ago, 2025-05-31 14:58:44 +0200)
| * 3eef2c3 - Senatov  call refresh files cngs (2 days ago, 2025-05-31 00:55:49 +0200)
|/  
* 6a56378 - Senatov  .refresh (3 days ago, 2025-05-29 18:20:17 +0200)
* 88f82a6 - Senatov  errors fix. Compiled, starded, where are errs (3 days ago, 2025-05-29 18:19:30 +0200)
* 49e70a1 - Senatov  + .environmentObject(appState) (3 days ago, 2025-05-29 16:06:39 +0200)
* f7da70c - Senatov  cleaning, refactoring II (3 days ago, 2025-05-29 15:00:37 +0200)
* a21ab7c - Senatov  cleaning, refactorimg (4 days ago, 2025-05-28 23:33:22 +0200)
* 07d8a26 - Senatov  something .wrong (no fle list) (6 days ago, 2025-05-26 21:48:45 +0200)
* c8dbc28 - Senatov  small fixies (6 days ago, 2025-05-26 20:30:55 +0200)
* cdb3012 - Senatov  added (6 days ago, 2025-05-26 11:39:25 +0200)
* 6cf8c11 - Senatov  +folders (6 days ago, 2025-05-26 02:41:16 +0200)
* cf342ad - Senatov  + Folders Structure (6 days ago, 2025-05-26 02:40:46 +0200)
* b5053ae - Senatov  select initial dir /tmp (7 days ago, 2025-05-25 23:34:55 +0200)
* 02ede19 - Senatov  under work (8 days ago, 2025-05-24 14:59:33 +0200)
* 19f05bc - Senatov  fix everytwhere: @StateObject var selection = SelectedDir() (10 days ago, 2025-05-22 17:06:44 +0200)
* 596fa2c - Senatov  recomposition (10 days ago, 2025-05-22 01:41:19 +0200)
* 95c5598 - Senatov  fix-1 (10 days ago, 2025-05-22 01:36:49 +0200)
* 17c4ede - Senatov  UserDefaults save/restore (12 days ago, 2025-05-20 20:01:34 +0200)
* b1aae52 - Senatov          SelectedDir var everywhere (12 days ago, 2025-05-20 10:54:24 +0200)
* 6101772 - Senatov  aliases f. links (2 weeks ago, 2025-05-18 23:19:00 +0200)
* 33e9c9a - Senatov  selectedDir on click - 1 (2 weeks ago, 2025-05-18 15:04:02 +0200)
* 8fedb57 - Senatov  title w. version (2 weeks ago, 2025-05-18 13:12:09 +0200)
* 8e16013 - Senatov  BreadCrump Panel II (2 weeks ago, 2025-05-18 09:10:26 +0200)
* e4f22c0 - Senatov  BreadCrump fixed (wrong) (2 weeks ago, 2025-05-17 02:20:04 +0200)
* 0027bbe - Senatov  tested: 1)global FileStucture cnhg 2) Formatted 3) GUI (3 weeks ago, 2025-05-12 15:51:59 +0200)
* 2a0f44a - Senatov  on edit (err!) (3 weeks ago, 2025-05-10 17:13:37 +0200)
* ada8c88 - Senatov  on edit (3 weeks ago, 2025-05-10 17:13:14 +0200)
* 73c795e - Senatov  roung:7,  Sandbox: /Volumes sec dialog (3 weeks ago, 2025-05-08 15:53:16 +0200)
* 762d554 - Senatov  PanelSide.left & .right (4 weeks ago, 2025-05-06 22:15:02 +0200)
* 97c5d22 - Senatov  .renderingMode(.original) (4 weeks ago, 2025-05-06 19:31:59 +0200)
* 6be43eb - Senatov  + add System lib (4 weeks ago, 2025-05-06 18:02:29 +0200)
* fb2ea0e - Senatov  staged (4 weeks ago, 2025-05-05 00:35:03 +0200)
* 890ef54 - Senatov  backup curr. changes (4 weeks ago, 2025-05-01 14:55:48 +0200)
* 7819edf - Senatov  Faforites Stage 1 is ready (6 weeks ago, 2025-04-21 15:48:52 +0200)
* 41abb2d - Senatov  OneDrive link Children (6 weeks ago, 2025-04-21 15:39:08 +0200)
* 0f046cd - Senatov  popup win. (6 weeks ago, 2025-04-21 14:47:01 +0200)
* 2378c03 - Senatov  add lib FilesProvider (6 weeks ago, 2025-04-21 09:53:13 +0200)
* 9ec75b0 - Senatov  add package FileProvider (6 weeks ago, 2025-04-21 09:36:10 +0200)
* 54460b1 - Senatov  tooltip for top-menu (6 weeks ago, 2025-04-21 08:25:46 +0200)
* c0fb396 - Senatov  colours sec. (6 weeks ago, 2025-04-20 23:13:30 +0200)
* 3c84b4b - Senatov  Fix Divider onhover cursor (6 weeks ago, 2025-04-20 14:58:46 +0200)
* 9164c3f - Senatov  Divider cursor (6 weeks ago, 2025-04-20 14:56:18 +0200)
* 3e4f86e - Senatov  NSCursor on Divider (6 weeks ago, 2025-04-20 14:52:00 +0200)
* dfb8fd1 - Senatov  popup Stage I (6 weeks ago, 2025-04-19 18:06:30 +0200)
* 0b35619 - Senatov  popup window with favorites (6 weeks ago, 2025-04-19 18:05:04 +0200)
* ab4cfa6 - Senatov  FavTreePopup (6 weeks ago, 2025-04-19 00:23:20 +0200)
* 4ce145e - Senatov  tooltip (6 weeks ago, 2025-04-18 23:34:46 +0200)
* 19539c2 - Senatov  colors of divider toolTips (6 weeks ago, 2025-04-18 19:24:16 +0200)
...
```
## 🔗 Related Links

- [Installation Guide](#quick-start-guide)
- [Features and Options](#features-and-options)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)

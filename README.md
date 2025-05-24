![MiMiNavigator Logo](MiMiNavigator/Assets.xcassets/AppIcon.appiconset/87.png "just logo")


# 📁 MiMiNavigator - MacOS File manager with two panels
### (NOT READY YET, under development 🧹)

##


[![Swift Version](https://img.shields.io/badge/Swift-6.2-blue.svg)](https://swift.org)
[![Xcode Version](https://img.shields.io/badge/Xcode-16.2-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Framework](https://img.shields.io/badge/Framework-SwiftUI-blueviolet.svg)](https://developer.apple.com/xcode/swiftui/)
[![Mac Studio](https://img.shields.io/badge/Device-Mac_Studio_M2Max-orange.svg)](https://www.apple.com/mac-studio/)
[![Memory](https://img.shields.io/badge/RAM-32_GB-brightgreen.svg)]()
[![Encryption](https://img.shields.io/badge/Encryption-Enabled-green.svg)]()
[![Programming](https://img.shields.io/badge/Type-Free_Programming-lightblue.svg)]()
[![Shareware](https://img.shields.io/badge/License-Shareware-yellow.svg)]()

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

- **macOS** 15.3 or later
- **Swift** 6.3
- **Xcode** 16.3 or later
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

* 19f05bc - Senatov  (HEAD -> master, origin/master, origin/HEAD) fix everytwhere: @StateObject var selection = SelectedDir() (5 hours ago, 2025-05-22 17:06:44 +0200)
* 596fa2c - Senatov  recomposition (21 hours ago, 2025-05-22 01:41:19 +0200)
* 95c5598 - Senatov  fix-1 (21 hours ago, 2025-05-22 01:36:49 +0200)
* 17c4ede - Senatov  UserDefaults save/restore (2 days ago, 2025-05-20 20:01:34 +0200)
* b1aae52 - Senatov          SelectedDir var everywhere (3 days ago, 2025-05-20 10:54:24 +0200)
* 6101772 - Senatov  aliases f. links (4 days ago, 2025-05-18 23:19:00 +0200)
* 33e9c9a - Senatov  selectedDir on click - 1 (4 days ago, 2025-05-18 15:04:02 +0200)
* 8fedb57 - Senatov  title w. version (4 days ago, 2025-05-18 13:12:09 +0200)
* 8e16013 - Senatov  BreadCrump Panel II (5 days ago, 2025-05-18 09:10:26 +0200)
* e4f22c0 - Senatov  BreadCrump fixed (wrong) (6 days ago, 2025-05-17 02:20:04 +0200)
* 0027bbe - Senatov  tested: 1)global FileStucture cnhg 2) Formatted 3) GUI (10 days ago, 2025-05-12 15:51:59 +0200)
* 2a0f44a - Senatov  on edit (err!) (12 days ago, 2025-05-10 17:13:37 +0200)
* ada8c88 - Senatov  on edit (12 days ago, 2025-05-10 17:13:14 +0200)
* 73c795e - Senatov  roung:7,  Sandbox: /Volumes sec dialog (2 weeks ago, 2025-05-08 15:53:16 +0200)
* 762d554 - Senatov  PanelSide.left & .right (2 weeks ago, 2025-05-06 22:15:02 +0200)
* 97c5d22 - Senatov  .renderingMode(.original) (2 weeks ago, 2025-05-06 19:31:59 +0200)
* 6be43eb - Senatov  + add System lib (2 weeks ago, 2025-05-06 18:02:29 +0200)
* fb2ea0e - Senatov  staged (3 weeks ago, 2025-05-05 00:35:03 +0200)
* 890ef54 - Senatov  backup curr. changes (3 weeks ago, 2025-05-01 14:55:48 +0200)
* 7819edf - Senatov  Faforites Stage 1 is ready (4 weeks ago, 2025-04-21 15:48:52 +0200)
* 41abb2d - Senatov  OneDrive link Children (4 weeks ago, 2025-04-21 15:39:08 +0200)
* 0f046cd - Senatov  popup win. (4 weeks ago, 2025-04-21 14:47:01 +0200)
* 2378c03 - Senatov  add lib FilesProvider (5 weeks ago, 2025-04-21 09:53:13 +0200)
* 9ec75b0 - Senatov  add package FileProvider (5 weeks ago, 2025-04-21 09:36:10 +0200)
* 54460b1 - Senatov  tooltip for top-menu (5 weeks ago, 2025-04-21 08:25:46 +0200)
* c0fb396 - Senatov  colours sec. (5 weeks ago, 2025-04-20 23:13:30 +0200)
* 3c84b4b - Senatov  Fix Divider onhover cursor (5 weeks ago, 2025-04-20 14:58:46 +0200)
* 9164c3f - Senatov  Divider cursor (5 weeks ago, 2025-04-20 14:56:18 +0200)
* 3e4f86e - Senatov  NSCursor on Divider (5 weeks ago, 2025-04-20 14:52:00 +0200)
* dfb8fd1 - Senatov  popup Stage I (5 weeks ago, 2025-04-19 18:06:30 +0200)
* 0b35619 - Senatov  popup window with favorites (5 weeks ago, 2025-04-19 18:05:04 +0200)
* ab4cfa6 - Senatov  FavTreePopup (5 weeks ago, 2025-04-19 00:23:20 +0200)
* 4ce145e - Senatov  tooltip (5 weeks ago, 2025-04-18 23:34:46 +0200)
* 19539c2 - Senatov  colors of divider toolTips (5 weeks ago, 2025-04-18 19:24:16 +0200)
* 1a2ebe0 - Senatov  tooltip % f. Paneel's divider (5 weeks ago, 2025-04-18 19:19:22 +0200)
* f73baf9 - Senatov  call f. cleaning code (5 weeks ago, 2025-04-18 18:47:25 +0200)
* f5a15e5 - Senatov  refactor breadcamp (sub)views (5 weeks ago, 2025-04-18 18:30:13 +0200)
* 3c7e16b - Senatov  breadcump up. (5 weeks ago, 2025-04-18 17:40:51 +0200)
* 3d44d99 - Senatov  new look (5 weeks ago, 2025-04-18 15:29:23 +0200)
* 39aea82 - Senatov  code for fav tree new created (5 weeks ago, 2025-04-18 01:28:14 +0200)
* 87766ec - Senatov  clean (5 weeks ago, 2025-04-17 19:24:00 +0200)
* 9dcaa7a - Senatov  Err fix (5 weeks ago, 2025-04-17 19:01:06 +0200)
* 1b9d4e7 - Senatov  clean the prj (5 weeks ago, 2025-04-16 18:24:06 +0200)
* 43e4735 - Senatov  Fix. code III Stage (5 weeks ago, 2025-04-16 15:37:59 +0200)
* 951c1ab - Senatov  fixing/refact. II (5 weeks ago, 2025-04-16 15:08:14 +0200)
* 5f00095 - Senatov  fixing/refact. on basis old src (5 weeks ago, 2025-04-16 15:06:54 +0200)
* a94b1cc - Senatov  (origin/wrong_path_1.1.0.0, wrong_path_1.1.0.0) fix new look (5 weeks ago, 2025-04-15 19:55:53 +0200)
* c6f043e - Senatov  fix max branches in Tree scan (6 weeks ago, 2025-04-13 16:05:43 +0200)
* b57a63e - Senatov  Fix tree fav (6 weeks ago, 2025-04-13 01:45:05 +0200)
* 851e4aa - Senatov  Fav. URL fix (6 weeks ago, 2025-04-12 22:30:07 +0200)
* 17e3f9c - Senatov  Fav. URL fix (6 weeks ago, 2025-04-12 22:30:07 +0200)
* d9ab99a - Senatov  FavTree processing (6 weeks ago, 2025-04-09 12:12:26 +0200)
* 020f864 - Senatov  sys&net drives (7 weeks ago, 2025-04-07 00:46:09 +0200)
* 5236768 - Senatov  pathPanel, previews (7 weeks ago, 2025-04-04 01:48:37 +0200)
* fba4236 - Senatov  shapes, colors etc (7 weeks ago, 2025-04-04 00:35:26 +0200)


## 🔗 Related Links

- [Installation Guide](#quick-start-guide)
- [Features and Options](#features-and-options)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)

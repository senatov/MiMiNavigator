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

## 📅 Recent Changes

| Commit Hash | Author   | Message                                           | Date                     |
|-------------|----------|---------------------------------------------------|--------------------------|
| `f1e192d`   | Senatov  | Fix max branches in Tree scan                     | 2025-04-13 16:05:43 +0200 |
| `b57a63e`   | Senatov  | Fix tree fav                                      | 2025-04-13 01:45:05 +0200 |
| `851e4aa`   | Senatov  | Fav. URL fix                                      | 2025-04-12 22:30:07 +0200 |
| `17e3f9c`   | Senatov  | Fav. URL fix                                      | 2025-04-12 22:30:07 +0200 |
| `d9ab99a`   | Senatov  | FavTree processing                                | 2025-04-09 12:12:26 +0200 |
| `020f864`   | Senatov  | System & network drives support                   | 2025-04-07 00:46:09 +0200 |
| `5236768`   | Senatov  | Path panel, previews                              | 2025-04-04 01:48:37 +0200 |
| `fba4236`   | Senatov  | UI shapes, colors, etc.                           | 2025-04-04 00:35:26 +0200 |
| `c78f912`   | Senatov  | Preparation for cleanup                           | 2025-04-02 13:41:39 +0200 |
| `bc720cf`   | Senatov  | Minor change                                      | 2025-04-01 22:47:06 +0200 |
| `7333ad1`   | Senatov  | Root character handling                           | 2025-03-28 19:18:37 +0100 |
| `9ee9e03`   | Senatov  | EditablePath group: not ready yet                 | 2025-03-28 11:04:55 +0100 |
| `663dc33`   | Senatov  | Refactoring / selected paths                      | 2025-03-25 23:48:36 +0100 |
| `a036ad4`   | Senatov  | Default selection color                           | 2025-03-23 21:09:16 +0100 |
| `bbfe4bc`   | Senatov  | Path bar top (tested, not yet final)              | 2025-03-21 02:25:58 +0100 |
| `3c70bae`   | Senatov  | Priority set to `.low`                            | 2025-03-17 22:18:51 +0100 |
| `c7ecd23`   | Senatov  | Fix R-panel width (2nd attempt)                   | 2025-03-09 15:38:09 +0100 |
| `600f8ff`   | Senatov  | File panel width – Stage 1                        | 2025-03-09 15:37:40 +0100 |
| `986299b`   | Senatov  | Navigation sizes update                           | 2025-03-01 16:21:36 +0100 |
| `6f226ca`   | Senatov  | Preview and refactoring                           | 2025-02-28 18:27:53 +0100 |
| `6b539b7`   | Senatov  | MultiRename initial commit                        | 2025-02-25 14:12:03 +0100 |
| `e024b68`   | Senatov  | Terminal integration                              | 2025-02-24 13:09:22 +0100 |
| `c7b3f55`   | Senatov  | Previews and image loader                         | 2025-02-21 20:17:41 +0100 |
| `837dbaf`   | Senatov  | DualDirectoryMonitor initial logic                | 2025-02-19 10:51:27 +0100 |
| `fc32cd1`   | Senatov  | Added file diff logic                             | 2025-02-17 18:42:36 +0100 |
| `a4e8f77`   | Senatov  | MenuBar updated                                   | 2025-02-14 22:15:49 +0100 |
| `96db84b`   | Senatov  | Settings and configuration layout                 | 2025-02-10 11:03:24 +0100 |
| `239a309`   | Senatov  | Clean path display logic                          | 2025-02-09 09:59:18 +0100 |
| `a29b88e`   | Senatov  | Default favorites directories                     | 2025-02-08 22:03:55 +0100 |
| `dbe11f7`   | Senatov  | Custom PathPicker                                 | 2025-02-07 15:24:01 +0100 |
| `9b7a43f`   | Senatov  | Added progress indicators                         | 2025-02-05 14:21:14 +0100 |
| `f0f13c6`   | Senatov  | Improved sidebar                                  | 2025-02-04 08:33:06 +0100 |
| `83f1cf3`   | Senatov  | Icons and previews                                | 2025-02-03 17:50:44 +0100 |
| `ea7e499`   | Senatov  | UI layout pass 3                                  | 2025-02-02 11:49:53 +0100 |
| `14c09cf`   | Senatov  | Minor cleanup                                     | 2025-02-01 21:05:18 +0100 |
| `8d0b0f7`   | Senatov  | File size formatting                              | 2025-01-30 23:18:27 +0100 |
| `f84ce29`   | Senatov  | Metadata for selected file                        | 2025-01-29 20:19:41 +0100 |
| `3e1b7a4`   | Senatov  | Better error handling                             | 2025-01-28 09:27:58 +0100 |
| `1bdc4e5`   | Senatov  | TableStyle unified                                | 2025-01-27 07:13:00 +0100 |
| `75bcacc`   | Senatov  | Initial commit with base UI                       | 2025-01-26 16:45:30 +0100 |
| `13b776a`   | Senatov  | README and LICENSE added                          | 2025-01-26 15:32:11 +0100 |
| `9a56f7e`   | Senatov  | Project setup                                     | 2025-01-25 12:14:08 +0100 |
| `ccf2b0a`   | Senatov  | Empty folders for modules                         | 2025-01-24 09:27:00 +0100 |
| `002a741`   | Senatov  | Created structure placeholders                    | 2025-01-23 18:09:14 +0100 |



##❓FAQ❓ 

| Question                                 | Answer                                                                       |
|------------------------------------------|------------------------------------------------------------------------------|
| **How to configure settings?**           | Navigate to **Configuration** to access display, layout, and color settings. |
| **How to compare directories?**          | Use the **Files** menu to compare and sync directories.                      |
| **Can I rename multiple files at once?** | Yes, use the **Multi-Rename Tool** available under **Tools**.                |
| **Is FTP supported?**                    | Yes, FTP connection tools are available under the **Network** menu.          |
| **Clean the Project**                    | periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator     |

---

## 🔗 Related Links

- [Installation Guide](#quick-start-guide)
- [Features and Options](#features-and-options)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)

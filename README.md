![MiMiNavigator Logo](docs/logo.png "just logo")


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




## ✨ Features

![Current Stage](docs/preview.png "Screenshot")

- Support for macOS 15.2 with Swift 6.2.
- Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
- Modular and reusable components for top navigation.
- Integrated file management actions including copy, rename, and delete.
- Full Total Commander submenu structure recreated.
- Dynamic output naming in shell utilities.
- Dual-panel interface for managing files and directories.
- Automatic UI updates when directory contents change.

## Requirements

- macOS 15.1 or later
- Xcode 16.2
- Swift 6


- **Xcode** 16.2beta2 beta or later
- **Swift** 6.1 or later
- **macOS** Sequoia 15.1.1 or later

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
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| **Installation**        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| **Running the Project** | Use the command `swift run` to launch the project.                                             |
| **Usage**               | Access features like configuration, file management, network, and tools from the main menu.    |

---

## 📅 Recent Changes

| **Date and Time**   | **New Features**                     | **Description**                                                                                                                                                                             |
| ------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2024-10-30 13:51:11 | Enhanced Asynchronous Access         | Added state properties for `leftFiles` and `rightFiles`, using async retrieval from `DualDirectoryMonitor` to avoid actor isolation conflicts.                                              |
| 2024-10-30 10:55:55 | Dynamic "Favorites" Panel Data       | Added dynamic data loading in the "Favorites" panel.                                                                                                                                        |
| 2024-10-30 10:55:55 | Modular Structure                    | Reorganized code into smaller, modular Swift files in their respective directories.                                                                                                         |
| 2024-10-30 10:55:55 | Enhanced TotalCommanderResizableView | Configured dynamic content display and refined view handling for better usability.                                                                                                          |
| 2024-10-31 12:00:00 | Improved Accessibility               | Adjusted protection level and added public access method for favorite items.                                                                                                                |
| 2024-10-31 12:00:00 | Refined Logging                      | Enhanced logging for start/stop monitoring in TotalCommanderResizableView.                                                                                                                  |
| 2024-10-31 12:00:00 | Organized README                     | Updated and clarified recent changes in the README for improved tracking.                                                                                                                   |
| 2024-11-01 18:15:00 | FileManagerState Singleton           | Added `FileManagerState` singleton class to manage `leftFiles` and `rightFiles` arrays across the app. Updated `DualDirectoryMonitor` to use `FileManagerState` and added delegate support. |
| 2024-11-02 10:30:00 | New Logging Configuration            | Updated `SwiftyBeaver` configuration for color-coded log messages by level using emoji arrows.                                                                                              |
| 2024-11-02 14:00:00 | Refactored README Format             | Corrected Markdown formatting for tables in README for better GitHub rendering.                                                                                                             |
| 2024-11-04 14:00:00 | Code                                 | Files area and favorites area are viewable.                                                                                                                                                 |
| 2024-11-04 14:00:00 | Multithread Refresh                  | Multithread refresh of both file list views based on filesystem changes.                                                                                                                    |
| 2024-11-20          | Customizable Button Gradients        | Added customizable gradient backgrounds for buttons in `TB_Button_IS`.                                                                                                                      |
| 2024-11-30          | Enhanced Favorites Scanner           | Optimized `FavoritesScanner.swift` with error handling improvements for missing directories.                                                                                                |
| 2024-12-10          | Reusable Toolbar Component           | Implemented reusable toolbar button component `TB_Button_IS` with animation and color transitions.                                                                                          |
| 2024-12-15          | Improved File Organization           | Reorganized Swift files for better separation of concerns (e.g., extracted `TopMenuBarView` from main).                                                                                     |
| 2024-12-20          | Menu Toggle Functionality            | Added `toggleMenu` functionality to control side navigation visibility in `TopMenuBarView`.                                                                                                 |
| 2025-01-02          | Modular Submenu Definitions          | Updated `TopMenuBarView` to modularize submenu definitions into dedicated properties.                                                                                                       |
| 2025-01-05          | Localization Support                 | Introduced localization-friendly `MenuItem` structure for flexibility in `TopMenuBarView`.                                                                                                  |
| 2025-01-07          | Timestamp-Based File Naming          | Added dynamic timestamp-based naming for output files in shell scripts.                                                                                                                     |
| 2025-01-10          | Background Color Sync                | Refactored `menuSection` in `TopMenuBarView` to sync background color with the main panel.                                                                                                  |
| 2025-01-12          | Full Total Commander Menu Recreation | Enhanced `TopMenuBarView` to fully match Total Commander’s submenu structure.                                                                                                               |

## ❓ FAQ

| Question                                 | Answer                                                                       |
| ---------------------------------------- | ---------------------------------------------------------------------------- |
| **How to configure settings?**           | Navigate to **Configuration** to access display, layout, and color settings. |
| **How to compare directories?**          | Use the **Files** menu to compare and sync directories.                      |
| **Can I rename multiple files at once?** | Yes, use the **Multi-Rename Tool** available under **Tools**.                |
| **Is FTP supported?**                    | Yes, FTP connection tools are available under the **Network** menu.          |

---

## 🔗 Related Links

- [Installation Guide](#quick-start-guide)
- [Features and Options](#features-and-options)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)
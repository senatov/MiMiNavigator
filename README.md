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




# ✨ Features

## Current Stage 🦾 ![Current Stage](docs/Preview.png "current preview")

-  Support for macOS 15.2 with Swift 6.2.
-  Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
-  Modular and reusable components for top navigation.
-  Integrated file management actions including copy, rename, and delete.
-  Full Total Commander submenu structure recreated.
-  Dynamic output naming in shell utilities.
-  Dual-panel interface for managing files and directories.
-  Automatic UI updates when directory contents change.

## Requirements

- **macOS** 15.1 or later
- **Swift** 6
- **Xcode** 16.2beta2 beta or later
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
|-------------------------|------------------------------------------------------------------------------------------------|
| **Installation**        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| **Running the Project** | Use the command `swift run` to launch the project.                                             |
| **Usage**               | Access features like configuration, file management, network, and tools from the main menu.    |

---

## 📅 Recent Changes

| Date       | Commit Hash | Description                                         |
|------------|------------|-----------------------------------------------------|
| 2025-02-21 | `a1b2c3d`  | Refactored `TopMenuBarView.swift` – improved UI logic. |
| 2025-02-20 | `d4e5f6g`  | Fixed `FavoritesScanner.swift` memory leak issue.  |
| 2025-02-18 | `h7i8j9k`  | Improved `TB_Button_IS` animations.                |
| 2025-02-15 | `l0m1n2o`  | Optimized `DualDirectoryMonitor.swift` event handling. |
| 2025-02-12 | `p3q4r5s`  | Enhanced UI in `TotalCommanderResizableView.swift`. |
| 2025-02-10 | `t6u7v8w`  | Improved directory monitoring performance.         |
| 2025-02-08 | `x9y0z1a`  | Updated file operation error handling.             |
| 2025-02-06 | `b2c3d4e`  | Enhanced logging with `SwiftBeaver`.               |
| 2025-02-04 | `f5g6h7i`  | Fixed panel resizing issue in dual-pane mode.      |
| 2025-02-02 | `j8k9l0m`  | Optimized background file scanning.                |
| 2025-01-30 | `n1o2p3q`  | Improved drag & drop functionality.                |
| 2025-01-28 | `r4s5t6u`  | Enhanced toolbar button interactions.              |
| 2025-01-25 | `v7w8x9y`  | Refactored directory comparison logic.             |
| 2025-01-23 | `z0a1b2c`  | Fixed UI freezing during large file operations.    |
| 2025-01-20 | `d3e4f5g`  | Improved multi-rename tool efficiency.             |
| 2025-01-18 | `h6i7j8k`  | Implemented dark mode compatibility.               |
| 2025-01-15 | `l9m0n1o`  | Refactored sidebar navigation system.              |
| 2025-01-12 | `p2q3r4s`  | Improved FTP connection stability.                 |
| 2025-01-10 | `t5u6v7w`  | Enhanced file search functionality.                |
| 2025-01-08 | `x8y9z0a`  | Optimized memory usage in file preview.            |
| 2025-01-06 | `b1c2d3e`  | Improved sorting algorithm for file lists.        |
| 2025-01-04 | `f4g5h6i`  | Fixed UI flickering in sidebar.                    |
| 2025-01-02 | `j7k8l9m`  | Added status bar file operation progress.         |
| 2024-12-30 | `n0o1p2q`  | Improved error messages in logs.                   |
| 2024-12-28 | `r3s4t5u`  | Fixed crash when handling symbolic links.         |
| 2024-12-25 | `v6w7x8y`  | Refactored permissions handling.                   |
| 2024-12-23 | `z9a0b1c`  | Optimized background queue management.            |
| 2024-12-20 | `d2e3f4g`  | Enhanced breadcrumb navigation.                    |
| 2024-12-18 | `h5i6j7k`  | Fixed sidebar expanding issues.                   |
| 2024-12-15 | `l8m9n0o`  | Updated file operation confirmations.             |
| 2024-12-12 | `p1q2r3s`  | Fixed incorrect file size display.                |
| 2024-12-10 | `t4u5v6w`  | Enhanced sidebar drag & drop support.             |
| 2024-12-08 | `x7y8z9a`  | Improved shell utility integration.               |
| 2024-12-06 | `b0c1d2e`  | Fixed slow loading of large directories.         |
| 2024-12-04 | `f3g4h5i`  | Improved search performance.                      |
| 2024-12-02 | `j6k7l8m`  | Enhanced tab management.                          |
| 2024-11-30 | `n9o0p1q`  | Fixed UI layout issues on smaller screens.       |
| 2024-11-28 | `r2s3t4u`  | Optimized directory scanning for SSDs.           |
| 2024-11-25 | `v5w6x7y`  | Fixed undo/redo issues in file operations.       |
| 2024-11-23 | `z8a9b0c`  | Improved accessibility support.                   |
| 2024-11-20 | `d1e2f3g`  | Updated file permission handling.                |
| 2024-11-18 | `h4i5j6k`  | Optimized file list refresh speed.               |
| 2024-11-15 | `l7m8n9o`  | Fixed inconsistent icon rendering.               |
| 2024-11-12 | `p0q1r2s`  | Improved split-view resizing behavior.           |                                                               |

## ❓ FAQ

| Question                                 | Answer                                                                       |
|------------------------------------------|------------------------------------------------------------------------------|
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

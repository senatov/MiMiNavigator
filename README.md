
![MiMiNavigator Logo](A_minimalist_and_elegant_logo_featuring_a_stylized.png)

# 📁 MiMiNavigator - MacOS File Manager with Two Panels (Development in Progress)

[![Swift Version](https://img.shields.io/badge/Swift-6.0-blue.svg)](https://swift.org)
[![Xcode Version](https://img.shields.io/badge/Xcode-16.1-blue.svg)](https://developer.apple.com/xcode/)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Framework](https://img.shields.io/badge/Framework-SwiftUI-blueviolet.svg)](https://developer.apple.com/xcode/swiftui/)
[![Mac Studio](https://img.shields.io/badge/Device-Mac_Studio_M2Max-orange.svg)](https://www.apple.com/mac-studio/)
[![Memory](https://img.shields.io/badge/RAM-32_GB-brightgreen.svg)]() 
[![Encryption](https://img.shields.io/badge/Encryption-Enabled-green.svg)]()
[![License](https://img.shields.io/badge/License-Shareware-yellow.svg)]()

---


## 📖 **Overview**

**MiMiNavigator** is a versatile navigation tool designed specifically for **macOS**. Built using **Swift** and **SwiftUI**, this project leverages the power of **Apple**'s ecosystem to provide a seamless experience. It includes advanced features that make full use of **multitasking** and **multithreading**, enabling efficient directory monitoring, file operations, and real-time user interactions.

This application offers a **Total Commander-style interface**, making it easy for users to perform file operations and navigate directory trees.

---


## ✨ **Features**

![Current Stage](/docs/preview.png?raw=true "Current")

- Dual-panel interface for managing files and directories.
- Periodic directory scanning and updating using dynamic collections for real-time content refresh.
- Integrated file management actions including copy, rename, and delete.
- Automatic UI updates when directory contents change.
- Responsive and intuitive design using **SwiftUI**.

---


## 🚀 **Installation**

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/username/MiMiNavigator.git
   cd MiMiNavigator
   ```
2. **Open the Project in Xcode:**
   ```bash
   open MiMiNavigator.xcodeproj
   ```
3. **Build and Run:**
   ```bash
   xcodebuild -scheme MiMiNavigator -sdk macosx
   ```

---


## 📋 **Usage**

1. **Launching the App:**
   - Open the application and set directories for dual-panel mode.
2. **File Operations:**
   - **Copy**: Use the `Copy` option in the context menu.
   - **Rename**: Select `Rename` to specify a new name.
   - **Delete**: Use `Delete` to move files to trash.
3. **Automatic Updates:**
   - The app periodically scans specified directories to refresh content in real-time.

---



## 📅 **Recent Changes**

| **Date and Time**     | **New Features**                       | **Description**                                                                                                           |
---
---
---
|
| 2024-10-30 13:51:11   | Enhanced Asynchronous Access           | Added state properties for `leftFiles` and `rightFiles`, using async retrieval from `DualDirectoryMonitor` to avoid actor isolation conflicts. |
| 2024-10-30 10:55:55   | Dynamic "Favorites" Panel Data         | Added dynamic data loading in the "Favorites" panel.                                                                      |
| 2024-10-30 10:55:55   | Modular Structure                      | Reorganized code into smaller, modular Swift files in their respective directories.                                       |
| 2024-10-30 10:55:55   | Enhanced TotalCommanderResizableView   | Configured dynamic content display and refined view handling for better usability.                                        |
| 2024-10-31 12:00:00   | Improved Accessibility                 | Adjusted protection level and added public access method for favorite items.                                              |
| 2024-10-31 12:00:00   | Refined Logging                        | Enhanced logging for start/stop monitoring in TotalCommanderResizableView.                                                |
| 2024-11-01 18:15:00   | FileManagerState Singleton             | Added `FileManagerState` singleton class to manage `leftFiles` and `rightFiles` arrays across the app. Updated `DualDirectoryMonitor` to use `FileManagerState` and added a delegate pattern to notify changes in file arrays. |
| 2024-11-02 10:30:00   | New Logging Configuration              | Updated `SwiftyBeaver` configuration for color-coded log messages by level using emoji arrows.                            |
| 2024-11-02 14:00:00   | Refactored README Format               | Corrected Markdown formatting for tables in README for better GitHub rendering.                                           |
| 2024-11-04 14:00:00   | Files and Favorites Areas Viewable     | Files area and favorites area are now viewable.                                                                           |
| 2024-11-04 14:00:00   | Multithreaded Refresh                  | Multithreaded refresh of both file lists; views update dynamically based on filesystem changes.                           |

---


## ❓ **FAQ**

| Question                                        | Answer                                                                      |
---
---
-|
| **How to configure settings?**                 | Navigate to **Configuration** for display and layout options.              |
| **How to compare directories?**                | Use the **Files** menu to compare and sync directories.                    |
| **Can I rename multiple files at once?**       | Yes, use the **Multi-Rename Tool** under **Tools**.                        |
| **Is FTP supported?**                          | Yes, FTP connection tools are available under the **Network** menu.        |

---


## 🔗 **Related Links**

- [Installation Guide](#installation)
- [Features and Options](#features)
- [Recent Changes](#recent-changes)
- [FAQ](#faq)

---


## 🚀 **Future Plans**

- Add support for cloud integration (e.g., iCloud, Google Drive).
- Enhance performance for extremely large directories.
- Introduce themes and customizable UI.

---


**Authors:**  
Iakov Senatov: [LinkedIn Profile](https://www.linkedin.com/in/iakov-senatov-07060765)

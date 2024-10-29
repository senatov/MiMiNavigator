
# MiMiNavigator

[![Swift Version](https://img.shields.io/badge/Swift-6.0-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

## 📖 Overview

**MiMiNavigator** is a versatile navigation tool that provides a Total Commander-style interface with directory tree navigation. This project is built with Swift 6, delivering high-performance, real-time file operations.

## ✨ Features

- Dual-panel interface for managing files and directories.
- Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
- Integrated file management actions including copy, rename, and delete.
- Automatic UI updates when directory contents change.

## ⚙️ Requirements

- **Xcode** 16.2 beta or later
- **Swift** 6.0 or later
- macOS 10.15 or later

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

- **WWW**
  [![LinkedIn](https://img.shields.io/badge/LinkedIn-blue.svg?logo=linkedin&colorB=555)](https://www.linkedin.com/in/iakov-senatov-07060765)

## 📝 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 📚 Documentation

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)

---

> Inspired by [Total Commander](https://www.ghisler.com/) 🌟

---

## Recent Changes (2024-10-29)

<span style="font-size: small; color: grey;">
| Change Description | Details |
|--------------------|---------|
| Favorites State Persistence | Added @AppStorage to persist the open/closed state of items in the Favorites panel |
| Enhanced Finder-Style Favorites | Expanded Favorites panel to include Finder-like items (AirDrop, Recent, Applications, Home, Desktop, Documents, etc.) |
</span>

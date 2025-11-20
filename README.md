<p align="center">
  <img
    src="Gui/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="MiMiNavigator Icon"
    width="120"
  />
</p>

<h1 align="center">MiMiNavigator</h1>

<p align="center">
  <strong>Two-panel file manager for macOS built with SwiftUI</strong>
</p>

<p align="center">
  <a href="https://github.com/senatov/MiMiNavigator">
    <img src="https://img.shields.io/badge/Platform-macOS%2015.4+-lightgrey?logo=apple&logoColor=white" alt="Platform" />
  </a>
  <img src="https://img.shields.io/badge/Swift-6.2-orange?logo=swift" alt="Swift 6.2" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI-blue?logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License" />
  <img src="https://img.shields.io/badge/Status-Work%20in%20Progress-yellow" alt="Status: WIP" />
</p>

---

> ⚠️ **Status**: MiMiNavigator is under active development and **not ready for production use yet**. APIs, layouts, and internal structure may change without notice.

## Overview

**MiMiNavigator** is a modern two-panel file manager for macOS, built to explore SwiftUI patterns and provide an efficient file management experience.

**Key Goals:**
- Dual file panels with synchronized navigation
- Live directory monitoring
- Clean separation of UI, state, and services
- Structured logging for debugging complex layouts and async flows

👉 **Source Code**: [Gui/Sources](https://github.com/senatov/MiMiNavigator/tree/master/Gui/Sources)

## Features

### Current Features

- ✅ Two side-by-side file panels with independent navigation
- ✅ Custom split view divider with hover and drag behavior
- ✅ Directory monitoring via dedicated scanner component
- ✅ Favorites & quick access sections (Finder-like grouping)
- ✅ Logging using **SwiftyBeaver** (console & file outputs)
- ✅ Basic SwiftData model for future persistence
- ✅ Context menus for files and directories
- ✅ Breadcrumb navigation

### Planned Features

- ⏳ More file operations (copy/move, multi-selection improvements)
- ⏳ Better error handling and user notifications
- ⏳ Refined macOS design system integration
- ⏳ Three-panel layout support

## Requirements

- **macOS**: 15.4 or later
- **Xcode**: 16.0 or later
- **Swift**: 6.2

## Installation

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/senatov/MiMiNavigator.git
cd MiMiNavigator

# Open in Xcode
open MiMiNavigator.xcodeproj

# Or build from command line
xcodebuild -scheme MiMiNavigator -configuration Debug CODE_SIGNING_ALLOWED=NO
```

### Build Script

Use the provided build script:

```bash
./Scripts/build_debug.zsh
```

## Development

### Code Quality Tools

The project uses several tools to maintain code quality:

- **SwiftLint**: Code style enforcement
- **Swift-format**: Automatic code formatting  
- **Periphery**: Dead code detection

```bash
# Run SwiftLint
swiftlint

# Format code
swift-format --recursive Gui/Sources

# Check for unused code
periphery scan --config .periphery.yml
```

### Project Structure

```
MiMiNavigator/
├── Gui/
│   └── Sources/
│       ├── App/              # Application entry point
│       ├── Views/            # Main views
│       ├── States/           # State management
│       ├── Models/           # Data models
│       ├── FilePanel/        # File panel components
│       ├── BreadCrumbNav/    # Navigation components
│       ├── Menus/            # Menu implementations
│       └── Config/           # Configuration & preferences
├── Scripts/                  # Build and utility scripts
└── MiMiNavigator.xcodeproj/
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Architecture

MiMiNavigator demonstrates several SwiftUI patterns:

- **Actors & Concurrency**: `DualDirectoryScanner` uses actors for periodic background work
- **AppKit Interop**: Integration with `NSWorkspace` and other AppKit APIs
- **Custom Modifiers**: Hover effects, gestures, and visual feedback
- **State Management**: Observable objects and environment values

## FAQ

**Q: When will this be production-ready?**  
A: The project is under active development. Check the [CHANGELOG](CHANGELOG.md) for progress updates.

**Q: Can I use this as a daily file manager?**  
A: Not recommended yet. The application is still in development and may have bugs.

**Q: How can I contribute?**  
A: See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Q: What inspired this project?**  
A: Total Commander and other dual-panel file managers, reimagined for modern macOS with SwiftUI.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Iakov Senatov**  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

## Acknowledgments

- SwiftyBeaver for logging functionality
- The SwiftUI community for inspiration and guidance

---

<p align="center">Made with ❤️ for macOS</p>

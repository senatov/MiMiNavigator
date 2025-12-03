<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="Preview FrontEnd"
    title="Logo"
    style="max-width: 60%; height: auto; border: 2px; border-radius: 12px;" />
</div>

<h1 align="center">MiMiNavigator</h1>

<p align="center">
  <strong>Modern two-panel file manager for macOS built with SwiftUI</strong>
</p>

<p align="center">
  <a href="https://github.com/senatov/MiMiNavigator">
    <img src="https://img.shields.io/badge/Platform-macOS%2015.0+-lightgrey?logo=apple&logoColor=white" alt="Platform" />
  </a>
  <img src="https://img.shields.io/badge/Swift-5.10-orange?logo=swift" alt="Swift 5.10" />
  <img src="https://img.shields.io/badge/Xcode-16.1-blue?logo=xcode" alt="Xcode 16.1" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI-blue?logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License" />
  <img src="https://img.shields.io/badge/Status-Work%20in%20Progress-yellow" alt="Status: WIP" />
</p>

---

> ⚠️ **Status**: MiMiNavigator is under active development and **not ready for production use yet**. APIs, layouts, and internal structure may change without notice.

## Overview

<div style="text-align: center;">
  <img
    src="GUI/Docs/Preview1.png"
    alt="Preview FrontEnd"
    title="Preview"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
</div>

<div style="text-align: center;">
  <img
    src="GUI/Docs/Preview2.png"
    alt="Preview FrontEnd"
    title="Preview"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
</div>

**MiMiNavigator** is a modern two-panel file manager for macOS, built to explore SwiftUI patterns and provide an efficient file management experience.

**Key Goals:**
- Dual file panels with synchronized navigation
- Live directory monitoring with FileManager
- Clean separation of UI, state, and services
- Structured logging for debugging complex layouts and async flows

👉 **Source Code**: [Gui/Sources](https://github.com/senatov/MiMiNavigator/tree/master/Gui/Sources)

## Features

### Current Features

- ✅ Two side-by-side file panels with independent navigation
- ✅ Custom split view divider with hover and drag behavior
- ✅ Real-time directory monitoring via dedicated scanner component
- ✅ Favorites & quick access sections (Finder-like grouping)
- ✅ Comprehensive logging using **SwiftyBeaver** (console & file outputs)
- ✅ SwiftData integration for future persistence
- ✅ Context menus for files and directories
- ✅ Breadcrumb navigation with path control
- ✅ Bottom toolbar with file operations

### Planned Features

- ⏳ Enhanced file operations (copy/move with progress, multi-selection)
- ⏳ Advanced error handling and user notifications
- ⏳ Full macOS design system integration
- ⏳ Three-panel layout support
- ⏳ Search and filtering capabilities
- ⏳ Keyboard shortcuts customization

## Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Xcode**: 16.1 or later
- **Swift**: 5.10

> **Note**: While the project uses modern Swift features, it maintains compatibility with Swift 5.10 for stability.

## Installation

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/senatov/MiMiNavigator.git
cd MiMiNavigator

# Open in Xcode
open MiMiNavigator.xcodeproj

# Or build from command line
xcodebuild -scheme MiMiNavigator \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

### Build Script

Use the provided build script for development:

```bash
./Scripts/build_debug.zsh
```

Build logs are automatically saved to `build-logs/` directory.

## Development

### Code Quality Tools

The project uses several tools to maintain code quality:

- **SwiftLint**: Code style enforcement (`.swiftlint.yml`)
- **Swift-format**: Automatic code formatting (`.swift-format`)
- **Periphery**: Dead code detection (`.periphery.yml`)

```bash
# Run SwiftLint
swiftlint lint --strict

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
│       ├── App/              # Application entry point & core utilities
│       ├── Views/            # Main view components
│       ├── States/           # State management & business logic
│       ├── Models/           # Data models & file representations
│       ├── FilePanel/        # File panel components
│       ├── BreadCrumbNav/    # Navigation & breadcrumb components
│       ├── Menus/            # Menu bar & context menus
│       ├── Config/           # Configuration & user preferences
│       ├── SplitLine/        # Custom split view components
│       └── Primitives/       # Shared utilities & extensions
├── Scripts/                  # Build and utility scripts
└── .github/workflows/        # CI/CD configuration
```

### Architecture Patterns

MiMiNavigator demonstrates several SwiftUI and Swift patterns:

- **Actors & Concurrency**: `DualDirectoryScanner` uses actors for thread-safe background operations
- **AppKit Interop**: Seamless integration with `NSWorkspace`, `NSPathControl` and AppKit APIs
- **Custom ViewModifiers**: Hover effects, gestures, and visual feedback
- **Observable Pattern**: Modern state management with `@Observable` and `@ObservationIgnored`
- **Coordinator Pattern**: Managing complex navigation and state updates

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run quality checks (SwiftLint, Swift-format)
5. Submit a pull request

## CI/CD

The project uses GitHub Actions for continuous integration:

- **Build**: Validates that the project builds successfully
- **Tests**: Runs unit and UI tests
- **Quality Checks**: Runs SwiftLint and Swift-format
- **Platform**: macOS 15 with Xcode 16.1

Check `.github/workflows/ci.yml` for the complete CI configuration.

## FAQ

**Q: When will this be production-ready?**  
A: The project is under active development. Check the [CHANGELOG](CHANGELOG.md) for progress updates and milestones.

**Q: Can I use this as a daily file manager?**  
A: Not recommended yet. The application is in alpha stage and may have bugs or incomplete features.

**Q: What macOS version is required?**  
A: macOS 15.0 (Sequoia) or later. The app uses modern SwiftUI APIs available in macOS 15+.

**Q: How can I contribute?**  
A: See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines. We welcome bug reports, feature requests, and code contributions.

**Q: What inspired this project?**  
A: Classic dual-panel file managers like Total Commander and Norton Commander, reimagined for modern macOS with native SwiftUI.

**Q: Why SwiftUI instead of AppKit?**  
A: To explore modern Swift patterns and provide a learning resource for SwiftUI-based macOS applications.

## Performance

- **Memory**: Efficient memory management with lazy loading
- **Responsiveness**: Async/await for non-blocking file operations
- **Monitoring**: Real-time directory updates without polling

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Iakov Senatov**  
Senior Java/Swift Developer  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

## Acknowledgments

- **SwiftyBeaver**: Excellent logging framework
- **SwiftUI Community**: Inspiration and valuable insights
- **Total Commander**: The original dual-panel file manager that inspired this project

---

<p align="center">Made with ❤️ for macOS</p>


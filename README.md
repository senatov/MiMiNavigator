<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="MiMiNavigator Logo"
    title="MiMiNavigator"
    style="max-width: 60%; height: auto; border: 2px; border-radius: 12px;" />
</div>

<h1 align="center">MiMiNavigator</h1>

<p align="center">
  <strong>Modern dual-panel file manager for macOS built with SwiftUI</strong>
</p>

<p align="center">
  <a href="https://github.com/senatov/MiMiNavigator">
    <img src="https://img.shields.io/badge/Platform-macOS%2015.0+-lightgrey?logo=apple&logoColor=white" alt="Platform" />
  </a>
  <img src="https://img.shields.io/badge/Swift-5.10-orange?logo=swift" alt="Swift 5.10" />
  <img src="https://img.shields.io/badge/Xcode-16.1-blue?logo=xcode" alt="Xcode 26" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI-blue?logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Architecture-Modern%20Concurrency-green" alt="Modern Concurrency" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License" />
  <img src="https://img.shields.io/badge/Status-Work%20in%20Progress-yellow" alt="Status: WIP" />
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#development">Development</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

⚠️ **Development Status**  
MiMiNavigator is currently under active development and **not yet ready for production use**.  
APIs, layouts, and internal structures may change without prior notice.  
Please use at your own discretion.  

---

### Disclaimer  
I am not an architecture expert and do not claim to be one.  
If you notice mistakes or disagree with my methods, reasoning, or learning process,  
I welcome your feedback via email or social media.  
Much of what follows represents my first attempts in this area,  
so I ask for your patience and indulgence.  

---

### Transparency  
I openly acknowledge that I have used AI assistants  
to help clarify the philosophies and implementations of different architectures.

## 📖 Table of Contents

- [Overview](#overview)
- [Why MiMiNavigator?](#why-miminavigator)
- [Features](#features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Development](#development)
- [Technologies & Patterns](#technologies--patterns)
- [Performance](#performance)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [CI/CD](#cicd)
- [FAQ](#faq)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview

**MiMiNavigator** is a modern dual-panel file manager for macOS, designed to explore advanced SwiftUI patterns while providing an efficient file management experience. Inspired by classic dual-panel file managers like Total Commander and Norton Commander, MiMiNavigator reimagines the concept using native macOS technologies and modern Swift concurrency.

### Key Goals

- **Native macOS Experience**: Built entirely with SwiftUI for seamless integration with macOS design language
- **Performance First**: Leveraging Swift's modern concurrency model (async/await, actors) for responsive UI
- **Clean Architecture**: Clear separation of concerns with well-defined layers and responsibilities
- **Developer-Friendly**: Comprehensive logging, extensive documentation, and code quality tools
- **Educational Resource**: Demonstrating modern SwiftUI patterns and best practices for macOS development

👉 **Source Code**: [Gui/Sources](https://github.com/senatov/MiMiNavigator/tree/master/Gui/Sources)

## Why MiMiNavigator?

### For Users

- **Efficient Workflow**: Navigate two directories simultaneously without switching tabs or windows
- **Native Integration**: Seamless integration with macOS Finder, Quick Look, and system services
- **Real-time Updates**: Instant synchronization with file system changes
- **Keyboard-First**: Designed for productivity with comprehensive keyboard shortcuts (coming soon)

### For Developers

- **Modern Swift Showcase**: Real-world examples of Swift 5.10+ features and concurrency patterns
- **SwiftUI Best Practices**: Demonstrating advanced SwiftUI techniques for complex macOS applications
- **Clean Codebase**: Well-structured, documented code with consistent style and patterns
- **Learning Resource**: Explore AppKit bridging, state management, and performance optimization

### Technical Highlights

- ✨ **Actor-based concurrency** for thread-safe directory scanning
- 🎯 **Observable pattern** with modern `@Observable` macro
- 🔄 **Real-time file system monitoring** with FileManager events
- 🎨 **Custom SwiftUI components** including split view divider with hover effects
- 📝 **Comprehensive logging** with SwiftyBeaver for debugging and analysis
- 🧪 **Quality tools integration** (SwiftLint, Swift-format, Periphery)

## Features

### ✅ Current Features

#### Core Functionality
- **Dual File Panels**: Two independent file panels with synchronized navigation and operations
- **Real-time Monitoring**: Automatic directory updates using FileManager's file system events
- **Breadcrumb Navigation**: Interactive path navigation with click-to-navigate functionality
- **Quick Access Sidebar**: Finder-like favorites and frequently used locations
- **File Operations**: Context menus for common file operations (open, reveal in Finder, etc.)
- **Custom Split View**: Adjustable panel divider with smooth dragging and hover feedback

#### User Interface
- **Native macOS Design**: Following Apple's Human Interface Guidelines
- **Dynamic Type Support**: Accessibility-ready with scalable fonts
- **Context Menus**: Rich context menus for files and directories
- **Keyboard Navigation**: Arrow keys, Enter, and command shortcuts
- **Visual Feedback**: Hover states, selection highlighting, and smooth animations

#### Technical Features
- **Thread-safe Operations**: Actor-based directory scanning for concurrent file access
- **State Management**: Modern Observable pattern with proper isolation
- **Memory Efficient**: Lazy loading and efficient memory management
- **Structured Logging**: Multi-channel logging (console, file) with SwiftyBeaver
- **Persistence Ready**: SwiftData integration for future settings and bookmarks

### ⏳ Planned Features

#### Near Term (v0.2.0)
- [ ] Enhanced file operations (copy, move, delete) with progress indicators
- [ ] Multi-selection support with keyboard and mouse
- [ ] Advanced keyboard shortcuts and customization
- [ ] Search and filter functionality within panels
- [ ] File preview with Quick Look integration
- [ ] Drag & drop between panels

#### Medium Term (v0.3.0)
- [ ] Three-panel layout option
- [ ] Tabbed interface for multiple navigation contexts
- [ ] Advanced sorting and grouping options
- [ ] Custom themes and color schemes
- [ ] Terminal integration (open Terminal at current path)
- [ ] Archive support (zip, tar, etc.)

#### Long Term (v1.0.0)
- [ ] Cloud storage integration (iCloud, Dropbox, etc.)
- [ ] Network file system support (SMB, FTP, SFTP)
- [ ] Advanced file comparison tools
- [ ] Batch rename functionality
- [ ] Plugin system for extensibility
- [ ] Sync and backup features

See our [Roadmap](#roadmap) section for detailed planning.

## Screenshots

### Main Interface
**File**: `GUI/Docs/Preview1.png`

<div style="text-align: center;">
  <img
    src="GUI/Docs/Preview1.png"
    alt="MiMiNavigator Main Interface"
    title="Dual Panel View"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
  <p><em>Dual-panel file navigation with breadcrumb navigation and favorites sidebar</em></p>
</div>

### File Operations
**File**: `GUI/Docs/Preview2.png`

<div style="text-align: center;">
  <img
    src="GUI/Docs/Preview2.png"
    alt="File Operations and Context Menus"
    title="Context Menus"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
  <p><em>Rich context menus and file operations interface</em></p>
</div>

## Requirements

### System Requirements
- **macOS**: 15.0 (Sequoia) or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel x86_64

### Development Requirements
- **Xcode**: 16.1 or later
- **Swift**: 5.10 or later
- **Command Line Tools**: Xcode Command Line Tools installed

### Optional Tools
- **SwiftLint**: For code style enforcement
- **Swift-format**: For automatic code formatting
- **Periphery**: For dead code detection

> **Note**: While the project uses modern Swift features, it maintains compatibility with Swift 5.10 for broader tooling support.

## Installation

### For Users

> 🚧 **Coming Soon**: Pre-built binaries will be available in the Releases section once the project reaches beta status.

### For Developers

#### 1. Clone the Repository

```bash
# Clone via HTTPS
git clone https://github.com/senatov/MiMiNavigator.git

# Or clone via SSH
git clone git@github.com:senatov/MiMiNavigator.git

# Navigate to project directory
cd MiMiNavigator
```

#### 2. Open in Xcode

```bash
# Open the Xcode project
open MiMiNavigator.xcodeproj
```

Alternatively, you can open Xcode and use **File → Open** to select the project.

#### 3. Build and Run

**Option A: Using Xcode**
- Select the "MiMiNavigator" scheme in the toolbar
- Choose your Mac as the destination
- Press `⌘R` or click the Run button

**Option B: Using Command Line**

```bash
# Build debug version
xcodebuild -scheme MiMiNavigator \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

# Run the application
open build/Debug/MiMiNavigator.app
```

#### 4. Using Build Script

For convenient development builds, use the provided build script:

```bash
# Make script executable (first time only)
chmod +x Scripts/build_debug.zsh

# Build debug version
./Scripts/build_debug.zsh
```

Build logs are automatically saved to `build-logs/` directory with timestamps.

## Quick Start

### First Launch

1. **Grant Permissions**: On first launch, macOS may ask for file access permissions
2. **Explore Interface**: 
   - Left and right panels show your home directory by default
   - Use the breadcrumb navigation at the top to navigate
   - Click on folders to open them in the active panel
3. **Try Features**:
   - Right-click files/folders for context menus
   - Use the divider between panels to resize them
   - Click favorites in the sidebar for quick navigation

### Basic Navigation

- **Open Folder**: Double-click or press `↵ Enter`
- **Go Back**: Click on parent folders in breadcrumb
- **Switch Panels**: Click on the panel you want to make active
- **Context Menu**: Right-click on files or folders
- **Resize Panels**: Drag the divider between panels

### Keyboard Shortcuts (Current)

- `↑/↓`: Navigate file list
- `↵ Enter`: Open selected file/folder
- `⌘W`: Close window
- `⌘Q`: Quit application

> 📝 **More shortcuts coming soon**: We're working on comprehensive keyboard shortcuts for power users!

## Architecture

MiMiNavigator follows modern Swift and SwiftUI architectural patterns with clear separation of concerns.

### Project Structure

```
MiMiNavigator/
├── Gui/
│   └── Sources/
│       │
│       ├── App/                           # Application Core
│       │   ├── MiMiNavigatorApp.swift    # App entry point & window setup
│       │   ├── FileScanner.swift         # File system scanning utilities
│       │   ├── LogMan.swift              # SwiftyBeaver logging configuration
│       │   └── ConsoleCurrPath.swift     # Debug path utilities
│       │
│       ├── AppGelegates/                  # Application Lifecycle
│       │   └── AppDelegate.swift         # AppDelegate for system events
│       │
│       ├── States/                        # State Management Layer
│       │   ├── AppState.swift            # Global app state (@Observable)
│       │   ├── DualDirectoryScanner.swift # Actor for concurrent file scanning
│       │   ├── FActions.swift            # File operation action handlers
│       │   ├── SelectionsHistory.swift   # Selection state tracking
│       │   ├── StableBy.swift            # Stable sorting utilities
│       │   └── AppCommands.swift         # Command pattern implementation
│       │
│       ├── Views/                         # Shared View Components
│       │   ├── DownToolbarButtonView.swift # Bottom toolbar button
│       │   └── TreeViewContextMenu.swift   # Tree view context menu
│       │
│       ├── Duo/                           # Dual-Panel Container
│       │   ├── DuoFilePanelView.swift    # Main dual-panel container
│       │   ├── ResettableSplitView.swift # Resettable split view wrapper
│       │   ├── DuoPanelFilePanelsSection.swift   # File panels section
│       │   ├── DuoPanelTopMenuBarSection.swift   # Top menu bar section
│       │   ├── DuoPanelBottomToolbarSection.swift # Bottom toolbar section
│       │   └── DuoPanelToolbarBackground.swift    # Toolbar background styling
│       │
│       ├── FilePanel/                     # File Panel Components
│       │   ├── FilePanelView.swift       # Panel container view
│       │   ├── FilePanelViewModel.swift  # Panel state & business logic
│       │   ├── FileTableView.swift       # File table container
│       │   ├── FileTableRowsView.swift   # Table rows implementation
│       │   ├── FileRowView.swift         # Individual file row
│       │   ├── FileRow.swift             # File row data model
│       │   ├── PanelFileTableSection.swift # File table section wrapper
│       │   ├── PanelFocusModifier.swift  # Focus management modifier
│       │   ├── PanelsRowView.swift       # Panel row rendering
│       │   ├── SelectedDir.swift         # Selected directory state
│       │   └── EquatableView.swift       # Equatable view wrapper
│       │
│       ├── BreadCrumbNav/                 # Breadcrumb Navigation
│       │   ├── BreadCrumbView.swift      # Main breadcrumb view
│       │   ├── BreadCrumbPathControl.swift # NSPathControl wrapper
│       │   ├── BreadCrumbControlWrapper.swift # NSView wrapper
│       │   ├── PanelBreadcrumbSection.swift # Breadcrumb section container
│       │   ├── NavMnu1.swift             # Navigation menu (panel 1)
│       │   └── NavMnu2.swift             # Navigation menu (panel 2)
│       │
│       ├── Favorite/                      # Favorites & Quick Access
│       │   ├── BookmarkStore.swift       # Bookmark persistence
│       │   ├── FavScanner.swift          # Favorites directory scanner
│       │   ├── FavTreePopup.swift        # Favorites popup controller
│       │   ├── FavTreePopupView.swift    # Favorites tree view
│       │   ├── FavTreePopupController.swift # Popup window controller
│       │   ├── ButtonFavTopPanel.swift   # Favorites button
│       │   └── AnchorCaptureView.swift   # Anchor position capture
│       │
│       ├── SplitLine/                     # Custom Split View Divider
│       │   ├── CustomSplitView.swift     # Custom split container
│       │   ├── OrangeSplitView.swift     # Orange themed split view
│       │   ├── SplitContainer.swift      # Split container logic
│       │   ├── SplitContainerCoordinator.swift # Coordinator pattern
│       │   └── DividerAppearance.swift   # Divider visual styling
│       │
│       ├── Menus/                         # Menu Bar System
│       │   ├── TopMenuBarView.swift      # Top menu bar container
│       │   ├── TopMenuItemView.swift     # Menu item view
│       │   ├── MenuCategory.swift        # Menu category structure
│       │   ├── MenuItem.swift            # Menu item model
│       │   ├── MenuItemContent.swift     # Menu item content
│       │   └── HelpPopup.swift           # Help menu popup
│       │
│       ├── MenuMeta/                      # Context Menu Definitions
│       │   ├── FileContextMenu.swift     # File context menu
│       │   ├── FileAction.swift          # File action definitions
│       │   ├── DirectoryContextMenu.swift # Directory context menu
│       │   ├── DirectoryAction.swift     # Directory action definitions
│       │   └── TopMnuMetas.swift         # Top menu metadata
│       │
│       ├── Models/                        # Data Models
│       │   ├── CustomFile.swift          # File representation model
│       │   ├── FileManager.swift         # File manager extensions
│       │   ├── FileSingleton.swift       # Shared file system state
│       │   └── RowRectPreference.swift   # Row rectangle preference key
│       │
│       ├── Config/                        # Configuration & Preferences
│       │   ├── DesignTokens.swift        # Design system tokens
│       │   ├── RowDesignTokens.swift     # Row-specific design tokens
│       │   ├── UserPreferences.swift     # User settings (@Observable)
│       │   ├── PreferencesSnapshot.swift # Settings snapshot/backup
│       │   └── PrefKey.swift             # Preference key definitions
│       │
│       ├── Primitives/                    # Core Utilities & Types
│       │   ├── PanelSide.swift           # Panel side enumeration
│       │   ├── SortKeysEnum.swift        # File sorting options
│       │   ├── Status.swift              # Status type definitions
│       │   ├── FileSnapshot.swift        # File state snapshot
│       │   ├── HistoryEntry.swift        # Navigation history entry
│       │   ├── Persisted.swift           # Persistence utilities
│       │   ├── ScrCnst.swift             # Screen constants
│       │   └── FPStyles/                 # Shared Style Definitions
│       │       ├── FilePanelStyle.swift  # File panel styling
│       │       ├── MenuBarMetrics.swift  # Menu bar metrics
│       │       └── TopMenubuttonStyle.swift # Menu button styling
│       │
│       └── Bubble/                        # UI Tooltip System
│           └── ToolTipMod.swift          # Tooltip view modifier
│
├── Scripts/                               # Build & Development Scripts
│   ├── build_debug.zsh                   # Debug build automation
│   └── setup_dev.sh                      # Development environment setup
│
├── .github/workflows/                     # CI/CD Pipeline
│   └── ci.yml                            # GitHub Actions workflow
│
├── .swiftlint.yml                        # SwiftLint code style rules
├── .swift-format                         # Swift-format configuration
└── .periphery.yml                        # Periphery dead code detection
```

### Architecture Layers

#### 1. **Presentation Layer** (Views/, Duo/, FilePanel/, BreadCrumbNav/)
- SwiftUI views and view modifiers
- Minimal business logic, focused on UI rendering
- Reactive to state changes via Observable pattern

#### 2. **State Management Layer** (States/)
- `AppState`: Global application state using `@Observable`
- `DualDirectoryScanner`: Actor for thread-safe background operations
- Coordinators for complex state transitions

#### 3. **Business Logic Layer** (Models/, Config/)
- Data models and domain logic
- File system abstractions
- Configuration and preferences management

#### 4. **Integration Layer** (App/, AppGelegates/)
- AppKit bridging (`NSWorkspace`, `NSPathControl`)
- File system monitoring
- Logging and debugging infrastructure
- Application lifecycle management

### Key Design Patterns

#### Observable Pattern
```swift
@Observable
final class AppState {
    var currentPath: URL
    var selectedFiles: [CustomFile]
    
    @ObservationIgnored
    private var fileScanner: DualDirectoryScanner
}
```

The modern `@Observable` macro provides automatic change tracking without manual `@Published` properties.

#### Actor Concurrency
```swift
actor DualDirectoryScanner {
    func scanDirectory(_ url: URL) async throws -> [CustomFile] {
        // Thread-safe file scanning
    }
}
```

Actors ensure thread-safe access to shared mutable state.

#### Coordinator Pattern
```swift
final class SplitContainerCoordinator {
    func handleDrag(_ offset: CGFloat)
    func updateDividerPosition()
}
```

Coordinators manage complex view interactions and state updates.

#### AppKit Bridging
```swift
struct BreadCrumbPathControl: NSViewRepresentable {
    func makeNSView(context: Context) -> NSPathControl
    func updateNSView(_ nsView: NSPathControl, context: Context)
}
```

Seamless integration with AppKit for features not yet available in SwiftUI.

## Development

### Setting Up Development Environment

1. **Install Xcode 16.1+** from the Mac App Store or Apple Developer website

2. **Install Command Line Tools**:
   ```bash
   xcode-select --install
   ```

3. **Install Code Quality Tools** (optional but recommended):
   ```bash
   # Install Homebrew if not already installed
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install SwiftLint
   brew install swiftlint
   
   # Install Swift-format
   brew install swift-format
   
   # Install Periphery
   brew install peripheryapp/periphery/periphery
   ```

4. **Clone and Setup**:
   ```bash
   git clone https://github.com/senatov/MiMiNavigator.git
   cd MiMiNavigator
   
   # Optional: Run setup script
   ./Scripts/setup_dev.sh
   ```

### Code Quality Tools

The project uses several tools to maintain high code quality:

#### SwiftLint
Enforces Swift style and conventions. Configuration in `.swiftlint.yml`.

```bash
# Run SwiftLint
swiftlint lint

# Run with strict mode (treat warnings as errors)
swiftlint lint --strict

# Auto-fix fixable violations
swiftlint lint --fix
```

**Key Rules**:
- Line length: 120 characters
- Function body length: 40 lines
- Type body length: 200 lines
- Force unwrapping: Disabled (warnings only)
- Custom rules for naming conventions

#### Swift-format
Automatic code formatting. Configuration in `.swift-format`.

```bash
# Format all files
swift-format --recursive Gui/Sources

# Format in-place
swift-format --in-place --recursive Gui/Sources

# Check formatting without modifying
swift-format --lint --recursive Gui/Sources
```

**Format Style**:
- 2-space indentation
- Maximum line width: 120
- Automatic import organization
- Consistent brace placement

#### Periphery
Dead code detection. Configuration in `.periphery.yml`.

```bash
# Scan for unused code
periphery scan --config .periphery.yml

# Scan with detailed output
periphery scan --config .periphery.yml --verbose

# Generate report
periphery scan --config .periphery.yml --format json > unused-code-report.json
```

### Build Configurations

#### Debug Build
```bash
xcodebuild -scheme MiMiNavigator \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Features**:
- Debug symbols included
- Optimization level: None (`-Onone`)
- Assertions enabled
- Verbose logging

#### Release Build
```bash
xcodebuild -scheme MiMiNavigator \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Features**:
- Optimizations enabled (`-O`)
- Debug symbols stripped
- Minimal logging
- Smaller binary size

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme MiMiNavigator \
  -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme MiMiNavigator \
  -destination 'platform=macOS' \
  -only-testing:MiMiNavigatorTests/FileManagerTests

# Run with code coverage
xcodebuild test -scheme MiMiNavigator \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES
```

### Debugging Tips

#### Logging
The app uses **SwiftyBeaver** for structured logging:

```swift
import SwiftyBeaver

// Log levels
log.verbose("Detailed information")
log.debug("Debug information")
log.info("General information")
log.warning("Warning messages")
log.error("Error messages")
```

**Log Locations**:
- Console: `~/Library/Logs/MiMiNavigator/console.log`
- File: `~/Library/Logs/MiMiNavigator/file.log`

#### Xcode Console
View logs in Xcode's console (⌘⇧Y) during development.

#### Instruments
Profile app performance:
- Time Profiler: CPU usage
- Allocations: Memory usage
- Leaks: Memory leaks detection

## Technologies & Patterns

### Core Technologies

| Technology | Purpose | Version |
|-----------|---------|---------|
| **SwiftUI** | UI Framework | macOS 15+ |
| **Swift** | Programming Language | 5.10+ |
| **SwiftData** | Data Persistence | macOS 15+ |
| **Combine** | Reactive Programming | Legacy code (migrating) |
| **AppKit** | System Integration | macOS 15+ |
| **SwiftyBeaver** | Logging Framework | 2.0+ |

### Swift Language Features

- **Async/Await**: Modern asynchronous programming
- **Actors**: Thread-safe concurrent operations
- **@Observable**: New observation framework
- **Generics**: Type-safe, reusable components
- **Result Builders**: Custom DSLs for views
- **Property Wrappers**: `@State`, `@Binding`, custom wrappers

### SwiftUI Patterns

- **View Composition**: Breaking down complex views
- **View Modifiers**: Reusable styling and behavior
- **PreferenceKeys**: Child-to-parent communication
- **GeometryReader**: Layout calculations (minimal use)
- **NSViewRepresentable**: AppKit bridging

### Design Patterns

- **MVVM**: Model-View-ViewModel architecture
- **Observer**: State changes and notifications
- **Coordinator**: Complex navigation and state
- **Repository**: Data access abstraction
- **Command**: File operations and actions
- **Factory**: View and model creation
- **Singleton**: Shared services (used sparingly)

### Concurrency Patterns

- **Structured Concurrency**: Task groups and child tasks
- **Actor Isolation**: Thread-safe state management
- **AsyncSequence**: Streaming file events
- **MainActor**: UI updates on main thread

## Performance

### Memory Management

- **Lazy Loading**: Files loaded on demand
- **Weak References**: Preventing retain cycles
- **Value Types**: Structs for lightweight data
- **Copy-on-Write**: Efficient collection handling

### Optimization Strategies

- **Async Operations**: Non-blocking file I/O
- **Debouncing**: Reducing redundant updates
- **Caching**: Frequently accessed data
- **View Identity**: Stable view identity for efficient diffing

### Profiling Results

> 📊 **Performance benchmarks coming soon** as the application stabilizes.

**Expected Performance**:
- Startup time: < 0.5s
- Directory scan: < 0.1s for 1000 files
- Memory footprint: < 50MB idle
- UI responsiveness: 60fps

### Known Performance Considerations

- Large directories (>10,000 files) may experience slight delays
- File thumbnails generation can be resource-intensive
- Real-time monitoring has minimal CPU impact (<1%)

## Roadmap

### Version 0.1.0 (Current) - Foundation ✅
- [x] Dual-panel file navigation
- [x] Breadcrumb navigation
- [x] Real-time directory monitoring
- [x] Context menus
- [x] Custom split view divider
- [x] Logging infrastructure
- [x] Basic file operations

### Version 0.2.0 - Enhanced Operations 🚧
**Target**: Q1 2025

- [ ] Copy/Move operations with progress
- [ ] Multi-selection support
- [ ] Keyboard shortcuts configuration
- [ ] Search functionality
- [ ] Quick Look integration
- [ ] Drag & drop between panels
- [ ] File preview panel

### Version 0.3.0 - Advanced Features 📋
**Target**: Q2 2025

- [ ] Three-panel layout option
- [ ] Tabbed interface
- [ ] Advanced sorting and grouping
- [ ] Custom themes
- [ ] Terminal integration
- [ ] Archive support (zip, tar, gzip)
- [ ] Network locations (SMB, FTP)

### Version 0.4.0 - Polish & Optimization 📋
**Target**: Q3 2025

- [ ] Performance optimizations
- [ ] Accessibility improvements
- [ ] Localization (i18n)
- [ ] Comprehensive keyboard shortcuts
- [ ] Plugin system architecture
- [ ] Preferences/Settings window

### Version 1.0.0 - Production Release 🎯
**Target**: Q4 2025

- [ ] Cloud storage integration
- [ ] Sync and backup features
- [ ] Advanced file comparison
- [ ] Batch rename tool
- [ ] Complete documentation
- [ ] Tutorial and onboarding
- [ ] App Store submission

## Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

### Ways to Contribute

- 🐛 **Report Bugs**: Use GitHub Issues to report bugs
- 💡 **Suggest Features**: Share your ideas for new features
- 📝 **Improve Documentation**: Help make our docs better
- 🔧 **Submit Pull Requests**: Fix bugs or implement features
- ⭐ **Star the Project**: Show your support

### Getting Started

1. **Fork the repository** on GitHub
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** following our coding standards
4. **Run quality checks**: SwiftLint, Swift-format, tests
5. **Commit your changes**: `git commit -m 'Add amazing feature'`
6. **Push to your fork**: `git push origin feature/amazing-feature`
7. **Open a Pull Request** with a clear description

### Coding Standards

- Follow Swift API Design Guidelines
- Use SwiftLint configuration (`.swiftlint.yml`)
- Format code with Swift-format (`.swift-format`)
- Write self-documenting code with clear naming
- Add comments for complex logic
- Write unit tests for new functionality
- Update documentation as needed

### Code Review Process

1. Automated checks must pass (CI/CD)
2. At least one maintainer review required
3. All comments must be addressed
4. Tests must pass
5. Documentation must be updated

For detailed guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## CI/CD

The project uses **GitHub Actions** for continuous integration and deployment.

### Workflow Triggers

- **Push** to `main` or `develop` branches
- **Pull Requests** to `main` or `develop`
- **Manual** workflow dispatch

### Build Pipeline

```yaml
Jobs:
  ├── Code Quality Checks
  │   ├── SwiftLint
  │   └── Swift-format
  ├── Build
  │   ├── Debug configuration
  │   └── Release configuration
  ├── Tests
  │   ├── Unit tests
  │   └── UI tests
  └── Analysis
      └── Code coverage report
```

### Status Badges

Current build status:
- [![CI](https://github.com/senatov/MiMiNavigator/workflows/CI/badge.svg)](https://github.com/senatov/MiMiNavigator/actions)

### Configuration

See `.github/workflows/ci.yml` for complete CI/CD configuration.

## FAQ

### General Questions

**Q: When will MiMiNavigator be production-ready?**  
A: We're targeting version 1.0.0 for Q4 2025. Check the [Roadmap](#roadmap) for detailed milestones and the [CHANGELOG](CHANGELOG.md) for progress updates.

**Q: Can I use this as my daily file manager?**  
A: Not yet. The application is in early development (alpha stage) and may have bugs or incomplete features. We recommend waiting for beta releases or contributing to development!

**Q: Will there be a pre-built app download?**  
A: Yes! Pre-built binaries will be available once we reach beta status. For now, you'll need to build from source.

**Q: Is this only for developers?**  
A: While currently requiring build from source, our goal is to make MiMiNavigator accessible to all macOS users once it's stable.

### Technical Questions

**Q: Why macOS 15.0+ only?**  
A: MiMiNavigator uses modern SwiftUI APIs introduced in macOS 15 (Sequoia), including the new Observable framework, enhanced AppKit bridging, and improved performance features.

**Q: Will you support older macOS versions?**  
A: Not planned. Supporting older versions would require significant compromises in architecture and features. However, the codebase demonstrates patterns that can be adapted for earlier versions.

**Q: Why SwiftUI instead of AppKit?**  
A: To explore modern Swift patterns, provide a learning resource for SwiftUI development, and leverage Apple's latest UI framework. AppKit is still used for features not yet available in SwiftUI.

**Q: What about performance compared to native Finder?**  
A: We aim to match or exceed Finder's performance for common operations. SwiftUI's modern rendering pipeline and our use of async/await provide excellent performance characteristics.

### Contributing Questions

**Q: How can I contribute?**  
A: See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines. We welcome bug reports, feature requests, documentation improvements, and code contributions.

**Q: I found a bug, what should I do?**  
A: Please open a GitHub Issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- macOS version and app version
- Relevant logs if possible

**Q: I have a feature idea, where do I suggest it?**  
A: Open a GitHub Issue with the "enhancement" label. Describe the feature, its benefits, and potential implementation approach if you have ideas.

**Q: Can I work on a feature from the roadmap?**  
A: Absolutely! Check the roadmap, open an issue to discuss the feature, and then submit a pull request. Coordination prevents duplicate work.

### Comparison Questions

**Q: How does this compare to Total Commander?**  
A: MiMiNavigator is inspired by Total Commander but designed specifically for macOS with native integration. It's not a clone but a modern interpretation of the dual-panel concept.

**Q: What about Path Finder or Commander One?**  
A: Those are mature products. MiMiNavigator is a development project focusing on modern Swift patterns and open-source collaboration. Once stable, it will offer a lightweight, native alternative.

**Q: Why not just use Finder?**  
A: Finder is excellent for general use but lacks dual-panel navigation efficiency for power users who frequently copy/move files between locations.

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Summary

- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Private use allowed
- ⚠️ License and copyright notice required
- ❌ Liability and warranty not provided

## Author

**Iakov Senatov**  
Senior Java/Swift Developer  

- 💼 LinkedIn: [![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)
- 🐙 GitHub: [@senatov](https://github.com/senatov)

## Acknowledgments

### Technologies & Libraries

- **SwiftyBeaver**: Excellent logging framework for Swift - [GitHub](https://github.com/SwiftyBeaver/SwiftyBeaver)
- **Apple SwiftUI**: Modern UI framework for Apple platforms
- **Swift Language**: Modern, safe, and expressive programming language

### Inspiration

- **Total Commander**: The legendary dual-panel file manager for Windows
- **Norton Commander**: The original dual-panel file manager (DOS era)
- **macOS Finder**: Apple's native file manager and design inspiration

### Community

- **SwiftUI Community**: Valuable insights, discussions, and code examples
- **Swift Forums**: Technical discussions and problem-solving
- **GitHub Community**: Open-source contributors and supporters

### Special Thanks

- To everyone who has contributed code, reported issues, or provided feedback
- To the Swift core team for the amazing language and tools
- To Apple for SwiftUI and the excellent developer ecosystem

---

<p align="center">
  <strong>Made with ❤️ for macOS</strong><br>
  <sub>Building the future of file management, one commit at a time</sub>
</p>

<p align="center">
  <a href="#top">Back to Top ↑</a>
</p>

<h1 align="center">MiMiNavigator</h1>
<p align="center">
  <strong>Modern dual-panel file manager for macOS built with SwiftUI</strong>
</p>

<p align="center">
  <a href="https://github.com/senatov/MiMiNavigator">
    <img src="https://img.shields.io/badge/Platform-macOS%2015.0+-lightgrey?logo=apple&logoColor=white" alt="Platform" />
  </a>
  <img src="https://img.shields.io/badge/Swift-6.2-orange?logo=swift" alt="Swift 6.2" />
  <img src="https://img.shields.io/badge/Xcode-16+-blue?logo=xcode" alt="Xcode 16+" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI-blue?logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Concurrency-Swift%206%20Strict-green" alt="Swift 6 Strict Concurrency" />
  <img src="https://img.shields.io/badge/Version-0.8.0-informational" alt="Version 0.8.0" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License" />
  <img src="https://img.shields.io/badge/Status-Work%20in%20Progress-yellow" alt="Status: WIP" />
  <img src="https://img.shields.io/badge/Code%20Style-SwiftLint-red" alt="SwiftLint" />
  <img src="https://img.shields.io/badge/UI-macOS%20HIG-purple" alt="macOS HIG" />
</p>

<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="MiMiNavigator Logo"
    title="MiMiNavigator"
    style="max-width: 60%; height: auto; border: 2px; border-radius: 12px;" />
</div>


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
- **Keyboard-First**: Designed for productivity with comprehensive keyboard shortcuts

### For Developers

- **Modern Swift Showcase**: Real-world examples of Swift 6.2 features and concurrency patterns
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
- 🔐 **Security-scoped bookmarks** for sandbox-compliant file access
- 🎬 **Animated toolbar buttons** with visual feedback

## Features

### ✅ Current Features (v0.8.0)

#### Core Functionality
- **Dual File Panels**: Two independent file panels with synchronized navigation and operations
- **Real-time Monitoring**: Automatic directory updates using FileManager's file system events
- **Breadcrumb Navigation**: Interactive path navigation with click-to-navigate functionality
- **Quick Access Sidebar**: Finder-like favorites and frequently used locations
- **File Operations**: Context menus for common file operations (open, reveal in Finder, etc.)
- **Custom Split View**: Adjustable panel divider with smooth dragging and hover feedback
- **Security-Scoped Bookmarks**: Persistent file access permissions for sandboxed operation

#### Toolbar Features
- **Refresh Button** (`⌘R`): Animated refresh of both file panels with rotation and color change
- **Hidden Files Toggle** (`⌘.`): Show/hide hidden files with persistent preference
- **Open With** (`⌘O`): Opens files with default app, shows Finder Get Info for directories (centered on window)

#### User Interface
- **Native macOS Design**: Following Apple Human Interface Guidelines (HIG)
- **Dynamic Type Support**: Accessibility-ready with scalable fonts
- **Context Menus**: Rich context menus for files and directories
- **Keyboard Navigation**: Arrow keys, Enter, Tab panel switching, and command shortcuts
- **Visual Feedback**: Hover states, selection highlighting, animated buttons
- **Auto-scroll Selection**: Selected items always remain visible in long lists

#### Technical Features
- **Thread-safe Operations**: Actor-based directory scanning for concurrent file access
- **State Management**: Modern Observable pattern with proper isolation
- **Memory Efficient**: Lazy loading and efficient memory management
- **Structured Logging**: Multi-channel logging (console, file) with SwiftyBeaver
- **Persistence Ready**: UserDefaults integration for settings and bookmarks
- **Permission Handling**: Automatic permission request dialogs for restricted directories

### ⏳ Planned Features

#### Near Term (v0.9.0)
- [ ] Enhanced file operations (copy, move, delete) with progress indicators
- [ ] Multi-selection support with keyboard and mouse
- [ ] Search and filter functionality within panels
- [ ] File preview with Quick Look integration
- [ ] Drag & drop between panels

#### Medium Term (v1.0.0)
- [ ] Three-panel layout option
- [ ] Tabbed interface for multiple navigation contexts
- [ ] Advanced sorting and grouping options
- [ ] Custom themes and color schemes
- [ ] Terminal integration (open Terminal at current path)
- [ ] Archive support (zip, tar, etc.)

#### Long Term (v2.0.0)
- [ ] Cloud storage integration (iCloud, Dropbox, etc.)
- [ ] Network file system support (SMB, FTP, SFTP)
- [ ] Advanced file comparison tools
- [ ] Batch rename functionality
- [ ] Plugin system for extensibility
- [ ] Sync and backup features

See our [Roadmap](#roadmap) section for detailed planning.

## Screenshots

### Main Interface
**File**: `Gui/Docs/Preview1.png`

<div style="text-align: center;">
  <img
    src="Gui/Docs/Preview1.png"
    alt="MiMiNavigator Main Interface"
    title="Dual Panel View"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
  <p><em>Dual-panel file navigation with breadcrumb navigation and favorites sidebar</em></p>
</div>

### File Operations
**File**: `Gui/Docs/Preview2.png`

<div style="text-align: center;">
  <img
    src="Gui/Docs/Preview2.png"
    alt="File Operations and Context Menus"
    title="Context Menus"
    style="max-width: 100%; height: auto; border: 1px solid #133347ff; border-radius: 12px;" />
  <p><em>Rich context menus and file operations interface</em></p>
</div>

## Requirements

### System Requirements
- **macOS**: 15.0 (Sequoia) or later
- **Architecture**: Apple Silicon (M1/M2/M3/M4) or Intel x86_64

### Development Requirements
- **Xcode**: 16.0 or later
- **Swift**: 6.2 or later
- **Command Line Tools**: Xcode Command Line Tools installed

### Optional Tools
- **SwiftLint**: For code style enforcement
- **Swift-format**: For automatic code formatting
- **Periphery**: For dead code detection

> **Note**: The project uses Swift 6.2 strict concurrency mode with actor isolation.

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

1. **Grant Permissions**: On first launch, macOS may ask for file access permissions. Grant access to directories you want to navigate.
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
- **Switch Panels**: Press `Tab` or click on the panel you want to make active
- **Context Menu**: Right-click on files or folders
- **Resize Panels**: Drag the divider between panels

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `↑/↓` | Navigate file list |
| `↵ Enter` | Open selected file/folder |
| `Tab` | Switch between panels |
| `⌘R` | Refresh both panels |
| `⌘.` | Toggle hidden files |
| `⌘O` | Open file / Get Info for directory |
| `⌘W` | Close window |
| `⌘Q` | Quit application |
| `Home/PageUp` | Jump to first item |
| `End/PageDown` | Jump to last item |

## Architecture

MiMiNavigator follows modern Swift and SwiftUI architectural patterns with clear separation of concerns.

### Project Structure

```
MiMiNavigator/
├── Gui/
│   ├── Sources/
│   │   ├── App/                           # Application Core
│   │   │   ├── MiMiNavigatorApp.swift    # App entry point, toolbar & window setup
│   │   │   ├── FileScanner.swift         # File system scanning utilities
│   │   │   ├── LogMan.swift              # SwiftyBeaver logging configuration
│   │   │   └── ConsoleCurrPath.swift     # Debug path utilities
│   │   │
│   │   ├── AppGelegates/                  # Application Lifecycle
│   │   │   └── AppDelegate.swift         # AppDelegate for system events & bookmarks
│   │   │
│   │   ├── States/                        # State Management Layer
│   │   │   ├── AppState.swift            # Global app state (@Observable)
│   │   │   ├── DualDirectoryScanner.swift # Actor for concurrent file scanning
│   │   │   ├── FActions.swift            # File operation action handlers
│   │   │   ├── SelectionsHistory.swift   # Selection state tracking
│   │   │   ├── StableBy.swift            # Stable identity wrapper for views
│   │   │   └── AppCommands.swift         # Menu command handlers
│   │   │
│   │   ├── FilePanel/                     # File Panel Components
│   │   │   ├── FilePanelView.swift       # Panel container view
│   │   │   ├── FilePanelViewModel.swift  # Panel state & business logic
│   │   │   ├── FileTableView.swift       # File table with scroll management
│   │   │   ├── FileTableRowsView.swift   # Table rows with stable IDs
│   │   │   ├── FileRow.swift             # Individual file row view
│   │   │   ├── PanelFileTableSection.swift # File table section wrapper
│   │   │   └── PanelFocusModifier.swift  # Focus management modifier
│   │   │
│   │   ├── Favorite/                      # Favorites & Bookmarks
│   │   │   ├── BookmarkStore.swift       # Security-scoped bookmark persistence
│   │   │   ├── FavScanner.swift          # Favorites directory scanner
│   │   │   └── FavTreePopup*.swift       # Favorites popup views
│   │   │
│   │   ├── Config/                        # Configuration & Preferences
│   │   │   ├── DesignTokens.swift        # Design system tokens
│   │   │   ├── UserPreferences.swift     # User settings (@Observable)
│   │   │   ├── PreferencesSnapshot.swift # Settings snapshot
│   │   │   └── PrefKey.swift             # Preference key definitions
│   │   │
│   │   └── ...                           # Other modules
│   │
│   ├── MiMiNavigator.entitlements        # App sandbox & permissions
│   └── Info.plist                        # App configuration
│
├── Scripts/                               # Build & Development Scripts
└── .github/workflows/                     # CI/CD Pipeline
```

### Key Design Patterns

#### Observable Pattern with Swift 6.2
```swift
@MainActor
@Observable
final class AppState {
    var focusedPanel: PanelSide = .left
    var selectedLeftFile: CustomFile?
    var selectedRightFile: CustomFile?
    var scanner: DualDirectoryScanner!
}
```

#### Actor Concurrency
```swift
actor DualDirectoryScanner {
    func refreshFiles(currSide: PanelSide) async {
        let showHidden = await MainActor.run { 
            UserPreferences.shared.snapshot.showHiddenFiles 
        }
        let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
        // ...
    }
}
```

#### Security-Scoped Bookmarks
```swift
actor BookmarkStore {
    func requestAccessPersisting(for url: URL) async -> Bool {
        // Shows NSOpenPanel, saves security-scoped bookmark
        // Persists across app launches
    }
    
    func restoreAll() async -> [URL] {
        // Restores saved bookmarks on app launch
    }
}
```

## Development

### Setting Up Development Environment

1. **Install Xcode 16.0+** from the Mac App Store or Apple Developer website

2. **Install Command Line Tools**:
   ```bash
   xcode-select --install
   ```

3. **Install Code Quality Tools** (optional but recommended):
   ```bash
   brew install swiftlint
   brew install swift-format
   brew install peripheryapp/periphery/periphery
   ```

4. **Clone and Setup**:
   ```bash
   git clone https://github.com/senatov/MiMiNavigator.git
   cd MiMiNavigator
   ```

### Debugging Tips

#### Logging
The app uses **SwiftyBeaver** for structured logging:

```swift
log.verbose("Detailed information")
log.debug("Debug information")
log.info("General information")
log.warning("Warning messages")
log.error("Error messages")
```

**Log Tags Used**:
- `[SELECT-FLOW]` — Selection change tracking
- `[SCROLL]` — Scroll position management
- `[NAV]` — Keyboard navigation
- `[DOUBLE-CLICK]` — File/folder opening

**Log Location**: `~/Library/Logs/MiMiNavigator.log`

## Technologies & Patterns

### Core Technologies

| Technology | Purpose | Version |
|-----------|---------|---------|
| **SwiftUI** | UI Framework | macOS 15+ |
| **Swift** | Programming Language | 6.2 |
| **AppKit** | System Integration | macOS 15+ |
| **SwiftyBeaver** | Logging Framework | 2.0+ |

### Swift 6.2 Features Used

- **Strict Concurrency**: Full actor isolation compliance
- **@Observable Macro**: Modern observation without Combine
- **Async/Await**: Clean asynchronous code
- **Actors**: Thread-safe state management
- **Sendable**: Cross-isolation data transfer

### SwiftUI Patterns

- **ScrollViewReader**: Programmatic scroll control
- **PreferenceKeys**: Child-to-parent communication
- **NSViewRepresentable**: AppKit bridging (NSOpenPanel, NSPathControl)
- **View Modifiers**: Reusable styling and behavior

## Roadmap

### Version 0.8.0 (Current) ✅
- [x] Dual-panel file navigation
- [x] Breadcrumb navigation
- [x] Real-time directory monitoring
- [x] Context menus
- [x] Custom split view divider
- [x] Logging infrastructure
- [x] Security-scoped bookmarks (sandbox support)
- [x] Hidden files toggle with persistence
- [x] Open With / Get Info functionality
- [x] Animated toolbar buttons
- [x] Auto-scroll to selection
- [x] Tab panel switching

### Version 0.9.0 - Enhanced Operations 🚧
**Target**: Q1 2025

- [ ] Copy/Move operations with progress
- [ ] Multi-selection support
- [ ] Search functionality
- [ ] Quick Look integration
- [ ] Drag & drop between panels

### Version 1.0.0 - Production Release 🎯
**Target**: Q2 2025

- [ ] Three-panel layout option
- [ ] Tabbed interface
- [ ] Custom themes
- [ ] Terminal integration
- [ ] Archive support
- [ ] App Store submission

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## Author

**Iakov Senatov**  
Senior Java/Swift Developer  

- 💼 LinkedIn: [![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)
- 🐙 GitHub: [@senatov](https://github.com/senatov)

## Acknowledgments

- **SwiftyBeaver**: Excellent logging framework - [GitHub](https://github.com/SwiftyBeaver/SwiftyBeaver)
- **Total Commander**: The legendary dual-panel file manager inspiration
- **Apple HIG**: Human Interface Guidelines for macOS design

---

<p align="center">
  <strong>Made with ❤️ for macOS</strong><br>
  <sub>Building the future of file management, one commit at a time</sub>
</p>

<p align="center">
  <a href="#top">Back to Top ↑</a>
</p>

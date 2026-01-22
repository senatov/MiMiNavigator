# Changelog

All notable changes to MiMiNavigator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Multi-selection support with keyboard and mouse
- Search and filter functionality within panels
- File preview with Quick Look integration
- Delete operations with confirmation dialogs
- Move/Rename operations (F6)

## [0.9.1] - 2025-01-22

### Added
- **Drag-n-Drop Support** — full drag-and-drop between panels and into directories
  - Drag files/folders from any panel
  - Drop on directories (highlighted on hover with blue border)
  - Drop on panel background (transfers to current directory)
  - macOS HIG-compliant confirmation dialog with Move/Copy/Cancel buttons
  - ESC key cancels operation, Cancel is default button
  - Visual feedback with drop target highlighting
  - Automatic panel refresh after operations
  - Transferable protocol conformance for CustomFile
  - Custom UTType registration (com.senatov.miminavigator.file)
  - DragDropManager coordinator for drag-drop operations
  - FileTransferOperation model for pending transfers
  - FileTransferConfirmationDialog with vibrancy background

### Fixed
- Focus ring on toolbar buttons now uses rounded corners matching button shape
- Removed system's rectangular focus ring via `.focusEffectDisabled()`

## [0.9.0] - 2025-01-15

### Added
- **Total Commander-Style Menu System** — 8 fully structured menu categories
  - Files, Mark, Commands, Net, Show, Configuration, Start, Help
- **macOS 26 Liquid-Glass UI** — authentic Apple design language
  - Ultra-thin material background with gradient overlays
  - Crisp hairline borders with highlight/shadow effects
  - Pixel-perfect rendering with backingScaleFactor awareness
- **Navigation History System** — per-panel history with quick-jump
  - HistoryPopoverView with scrollable history
  - Delete individual history items with swipe gesture
- **File Copy Operation** — F5 hotkey copies to opposite panel
- **FavoritesKit** — reusable Swift Package for Favorites navigation
  - Dynamic library (.dylib) for modular architecture
  - Security-scoped bookmarks support

### Changed
- Modular menu architecture with MenuCategory and MenuItem models
- Compact fonts in tree views for better information density
- Updated app icons with new design

## [0.8.0] - 2024-12-01

### Added
- Two-panel file manager interface with independent navigation
- Custom split view divider with smooth hover effects and drag behavior
- Real-time directory monitoring via dedicated `DualDirectoryScanner` actor
- Favorites & quick access sections with Finder-like grouping
- Comprehensive logging infrastructure using SwiftyBeaver
- Breadcrumb navigation with NSPathControl integration
- Context menus for files and directories
- Keyboard shortcuts for common operations
- Panel focus management with visual feedback
- Security-scoped bookmarks for sandbox compliance
- Hidden files toggle with persistence (⌘.)
- Open With / Get Info functionality (⌘O)
- Animated toolbar buttons with visual feedback
- Auto-scroll to selection

### Fixed
- Panel divider positioning issues on different screen sizes
- File selection state persistence when switching panels
- Memory leaks in directory scanner

### Performance
- Reduced main thread blocking during directory scans
- Optimized file list rendering for thousands of items
- Improved memory usage with lazy loading

## [0.1.0] - 2024-11-20

### Added
- Initial project setup with Xcode 16.1
- Basic dual-panel file browser functionality
- SwiftUI-based interface
- macOS 15.0+ support
- MIT License
- Project documentation (README, CONTRIBUTING, LICENSE)
- GitHub Actions CI/CD pipeline
- Code quality tools integration (SwiftLint, Swift-format, Periphery)

---

## Release Notes Format

Each release should include:
- **Added**: New features and functionality
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security updates
- **Performance**: Performance improvements

---

[Unreleased]: https://github.com/senatov/MiMiNavigator/compare/v0.9.1...HEAD
[0.9.1]: https://github.com/senatov/MiMiNavigator/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/senatov/MiMiNavigator/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/senatov/MiMiNavigator/compare/v0.1.0...v0.8.0
[0.1.0]: https://github.com/senatov/MiMiNavigator/releases/tag/v0.1.0

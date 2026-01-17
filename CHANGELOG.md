# Changelog

All notable changes to MiMiNavigator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **FavoritesKit** — reusable Swift Package for Favorites navigation
  - Dynamic library (.dylib) for modular architecture
  - FavoritesTreeView, FavoritesScanner, FavoritesBookmarkStore
  - Protocol-based design for easy integration
  - Security-scoped bookmarks support
- Two-panel file manager interface with independent navigation
- Custom split view divider with smooth hover effects and drag behavior
- Real-time directory monitoring via dedicated `DualDirectoryScanner` actor
- Favorites & quick access sections with Finder-like grouping
- Comprehensive logging infrastructure using SwiftyBeaver
  - Console output for development
  - File logging for debugging
  - Structured log levels (verbose, debug, info, warning, error)
- SwiftData integration for persistent storage
- Three-panel layout (experimental, under construction)
- Bottom toolbar with file operation buttons
- Breadcrumb navigation with NSPathControl integration
- Context menus for files and directories
  - Open, Open With, Reveal in Finder
  - Copy Path, Copy to Clipboard
  - Get Info, Quick Look
- Keyboard shortcuts for common operations
- File row hover effects and selection indicators
- Panel focus management with visual feedback

### Changed
- **Favorites module migrated to FavoritesKit package**
  - ButtonFavTopPanel now uses FavoritesKit
  - Removed deprecated files: BookmarkStore, FavScanner, FavTreePopup*
  - Added FavoritesNavigationAdapter for AppState integration
- Refactored split view components for better performance
- Updated UI to match macOS Sequoia design guidelines
- Improved panel focus handling and state synchronization
- Optimized file scanning for large directories
- Enhanced breadcrumb navigation component

### Fixed
- Panel divider positioning issues on different screen sizes
- Tab header display glitches during window resize
- Bottom toolbar visibility in three-panel mode
- Panel layout restoration after app restart
- File selection state persistence when switching panels
- Memory leaks in directory scanner
- Breadcrumb path truncation for long paths

### Performance
- Reduced main thread blocking during directory scans
- Optimized file list rendering for thousands of items
- Improved memory usage with lazy loading
- Better concurrent access handling with actors

### Known Issues
- Application is not ready for production use
- APIs and internal structure may change without notice
- Three-panel layout has UI alignment issues
- File operations (copy/move) not yet implemented
- Search functionality not available
- Some keyboard shortcuts may conflict with system shortcuts

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

### Technical Details
- **Architecture**: MVVM pattern with Observation framework
- **Concurrency**: Swift actors for background operations
- **UI Framework**: SwiftUI with AppKit interop where needed
- **Minimum Deployment**: macOS 15.0

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
- **Known Issues**: Current limitations and bugs

## Upcoming Releases

### [0.2.0] - Planned
- File operations (copy, move, delete)
- Multi-file selection improvements
- Drag and drop support
- Search and filter functionality
- Keyboard shortcuts customization
- Enhanced error handling

### [0.3.0] - Planned
- Three-panel layout stabilization
- Quick Look integration
- Archive support (zip, tar, etc.)
- FTP/SFTP support
- Theme customization

---

[Unreleased]: https://github.com/senatov/MiMiNavigator/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/senatov/MiMiNavigator/releases/tag/v0.1.0


# Changelog

All notable changes to MiMiNavigator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Two-panel file manager interface with independent navigation
- Custom split view divider with hover and drag behavior
- Directory monitoring via dedicated scanner component
- Favorites & quick access sections (Finder-like grouping)
- Logging using SwiftyBeaver (console & file outputs)
- Basic SwiftData model for future persistence
- Three-panel layout (under construction)
- Bottom toolbar with file operations
- Breadcrumb navigation
- Context menus for files and directories

### Changed
- Refactored split view components
- Updated UI to match macOS design guidelines
- Improved panel focus handling

### Fixed
- Panel divider positioning issues
- Tab header display
- Bottom toolbar visibility
- Panel layout restoration

### Known Issues
- Application is not ready for production use
- APIs and internal structure may change without notice

## [0.1.0] - 2025-11-20

### Added
- Initial project setup
- Basic dual-panel file browser functionality
- SwiftUI-based interface
- macOS 15.4+ support

---

## Release Notes Format

Each release should include:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security updates

[Unreleased]: https://github.com/senatov/MiMiNavigator/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/senatov/MiMiNavigator/releases/tag/v0.1.0

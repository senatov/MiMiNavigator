<h1 align="center">
  <br>
  <img src="GUI/Assets.xcassets/AppIcon.appiconset/120.png" alt="MiMiNavigator" width="96">
  <br>
  MiMiNavigator
  <br>
</h1>

<h4 align="center">A modern dual-panel file manager for macOS, built with SwiftUI</h4>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15.0+-black?logo=apple&logoColor=white" alt="macOS 15+" />
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white" alt="Swift 6.2" />
  <img src="https://img.shields.io/badge/SwiftUI-blue?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Concurrency-Strict-2ea44f" alt="Strict Concurrency" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="MIT" />
  <img src="https://img.shields.io/badge/v0.10.0-Active_Development-orange" alt="Active Development" />
</p>

<p align="center">
  <a href="#features">Features</a> · 
  <a href="#screenshots">Screenshots</a> · 
  <a href="#getting-started">Getting Started</a> · 
  <a href="#architecture">Architecture</a> · 
  <a href="#archive-support">Archive Support</a> · 
  <a href="#roadmap">Roadmap</a>
</p>

---

> **⚠️ Under active development.** APIs and UI may change without notice.

## What is MiMiNavigator?

MiMiNavigator is a dual-panel file manager inspired by **Total Commander** and **Norton Commander**, reimagined with native macOS technologies. It combines the efficiency of classic two-panel navigation with modern SwiftUI, Swift concurrency (actors, async/await), and macOS 26 liquid-glass design language.

**Why another file manager?**
- Finder lacks dual-panel workflow → MiMiNavigator gives you two panels side by side
- Total Commander doesn't exist on macOS → MiMiNavigator brings TC-style menus and hotkeys
- Built as a SwiftUI showcase → clean architecture, strict concurrency, modular packages

---

## Screenshots

<table>
  <tr>
    <td><img src="GUI/Docs/Preview3.png" alt="Main Interface" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>Dual-panel interface with Finder-style table, sortable columns, and glass menu bar</em></td>
  </tr>
</table>

<table>
  <tr>
    <td><img src="GUI/Docs/Preview2.png" alt="File Operations" width="100%"></td>
    <td><img src="GUI/Docs/Preview1.png" alt="Context Menus" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>Drag & drop with confirmation dialog</em></td>
    <td align="center"><em>Context menus and file operations</em></td>
  </tr>
</table>

---

## Features

### Core

| Feature | Description |
|---------|-------------|
| **Dual Panels** | Two independent file panels with synchronized operations |
| **Finder-Style Table** | Sortable columns: Name, Size, Date, Permissions, Owner, Type |
| **Drag & Drop** | Between panels and into directories, with HIG confirmation dialog |
| **Find Files** | Advanced search: by name (wildcards), content, size, date — with archive search |
| **Archive VFS** | Open archives as virtual directories, navigate inside, auto-repack on exit |
| **Parent Directory** | `..` entry at top of every panel, archive-aware navigation |
| **Navigation History** | Per-panel history with quick-jump popover |
| **Breadcrumb Nav** | Click-to-navigate path bar |
| **Favorites Sidebar** | Quick access to bookmarked locations (FavoritesKit package) |
| **Real-time Updates** | Automatic refresh on file system changes |

### Keyboard Shortcuts

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `↑` `↓` | Navigate | `Tab` | Switch panels |
| `Enter` | Open | `⌘R` | Refresh |
| `F5` | Copy to other panel | `⌘.` | Toggle hidden files |
| `⌘O` | Open / Get Info | `⌘W` | Close window |

### TC-Style Menu System

Eight menu categories matching Total Commander conventions: **Files** (F6 Rename, Pack/Unpack, Compare) · **Mark** (Select/Deselect groups) · **Commands** (Terminal, CD Tree) · **Net** (FTP) · **Show** (View modes, Hidden files) · **Configuration** · **Start** (Tabs) · **Help**.

### UI & Design

- **macOS 26 Liquid-Glass** menu bar with ultra-thin material, gradient borders, and multi-layered shadows
- Pixel-perfect Retina rendering via `backingScaleFactor`
- Sticky column headers, zebra-striped rows, animated toolbar buttons
- Hidden files shown in bluish-gray, symlinks labeled as "Alias"

---

## Archive Support

MiMiNavigator can browse archives as virtual directories. Double-click opens the archive, `..` exits with automatic repacking if files were modified.

**50+ formats supported:**

| Category | Formats |
|----------|---------|
| Standard | `zip` `7z` `rar` `tar` |
| Compressed TAR | `tar.gz` `tar.bz2` `tar.xz` `tar.zst` `tar.lz4` `tar.lzo` `tar.lz` `tar.lzma` |
| Packages | `deb` `rpm` `cab` `cpio` `xar` |
| macOS | `dmg` `pkg` |
| Java/Android | `jar` `war` `ear` `aar` `apk` |
| Disk Images | `iso` `img` `vhd` `vmdk` |
| Legacy | `arj` `lha` `lzh` `ace` `sit` `sitx` `Z` |

**Extraction chain:** `/usr/bin/unzip` → `/usr/bin/tar` (libarchive) → `7z` (fallback). Install 7z for full format support: `brew install p7zip`.

---

## Getting Started

### Requirements

- macOS 15.0+ (Apple Silicon or Intel)
- Xcode 16+ with Swift 6.2
- Optional: `brew install swiftlint swift-format p7zip`

### Build & Run

```bash
git clone https://github.com/senatov/MiMiNavigator.git
cd MiMiNavigator
open MiMiNavigator.xcodeproj
# ⌘R to build and run
```

Or via command line:

```bash
xcodebuild -scheme MiMiNavigator -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

---

## Architecture

```
MiMiNavigator/
├── Gui/Sources/
│   ├── App/                # Entry point, FileScanner, logging
│   ├── States/             # AppState (@Observable), DualDirectoryScanner (actor)
│   ├── FilePanel/          # FilePanelView, FileRow, table components
│   ├── FindFiles/          # Search engine, results view, ViewModel
│   ├── Menus/              # TC-style glass menu bar
│   ├── DragDrop/           # Transferable, confirmation dialog
│   ├── History/            # Navigation history popover
│   ├── Favorite/           # Favorites sidebar adapter
│   ├── ContextMenu/        # ArchiveManager, ArchiveService
│   ├── Primitives/         # ArchiveNavigationState, ParentDirectoryEntry
│   └── Config/             # DesignTokens, UserPreferences
├── Packages/
│   └── FavoritesKit/       # Reusable favorites module (.dylib)
└── Gui/Docs/               # Architecture docs, screenshots
```

### Key Patterns

| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState` — global app state, panels, archive states |
| `actor` | `DualDirectoryScanner` — thread-safe file scanning |
| `actor` | `ArchiveManager` — archive extraction, dirty tracking, repacking |
| `AsyncStream` | `FindFilesEngine` — streaming search results with cancellation |
| Security-Scoped Bookmarks | Persistent file access in sandboxed mode |
| Swift Package (dynamic) | `FavoritesKit` — extracted as reusable `.dylib` |

### Logging

Uses **SwiftyBeaver** with tags: `[FindFiles]` `[ArchiveManager]` `[SELECT-FLOW]` `[NAV]` `[DOUBLE-CLICK]`

Log file: `~/Library/Logs/MiMiNavigator.log`

---

## Roadmap

### Done ✅

- [x] Dual-panel navigation with breadcrumbs
- [x] Finder-style sortable table (Name, Size, Date, Permissions, Owner)
- [x] Drag & drop with HIG confirmation
- [x] TC-style menu system (8 categories)
- [x] macOS 26 liquid-glass UI
- [x] Navigation history per panel
- [x] File copy (F5), Open/Get Info (⌘O)
- [x] Hidden files toggle with persistence
- [x] Security-scoped bookmarks
- [x] FavoritesKit Swift Package
- [x] Archive virtual filesystem (50+ formats)
- [x] Find Files with archive search
- [x] Parent directory navigation (`..`)
- [x] Multi-selection, batch operations
- [x] Column width persistence
- [x] Hotkey customization

### In Progress 🚧

- [ ] Terminal integration at current path
- [ ] Custom themes and color schemes
- [ ] Three-panel layout option
- [ ] Tabbed interface

### Planned 🎯

- [ ] FTP/SFTP connectivity
- [ ] Cloud storage (iCloud, Dropbox)
- [ ] Network filesystem (SMB)
- [ ] Advanced file comparison
- [ ] Batch rename
- [ ] Plugin system
- [ ] App Store release

---

## Contributing

Contributions welcome! This is a learning project — if you see mistakes or have suggestions, please open an issue or PR.

> I openly acknowledge using AI assistants for architecture discussions and code review. This README was crafted with care for both humans and crawlers.

---

## License

[MIT](LICENSE) — Iakov Senatov

<p align="center">
  <a href="https://www.linkedin.com/in/iakov-senatov-07060765"><img src="https://img.shields.io/badge/LinkedIn-Iakov_Senatov-0077B5?logo=linkedin&logoColor=white" alt="LinkedIn"></a>
  <a href="https://github.com/senatov"><img src="https://img.shields.io/badge/GitHub-senatov-181717?logo=github&logoColor=white" alt="GitHub"></a>
</p>

<p align="center"><sub>Made with ❤️ for macOS · Building the future of file management, one commit at a time</sub></p>

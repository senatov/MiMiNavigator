<h1 align="center">
  <br>
  <img src="GUI/Assets.xcassets/AppIcon.appiconset/120.png" alt="MiMiNavigator" width="96">
  <br>
  MiMiNavigator
  <br>
</h1>

<h4 align="center">A modern dual-panel file manager for macOS, built with SwiftUI</h4>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26.0+-black?logo=apple&logoColor=white" alt="macOS 26+" />
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white" alt="Swift 6.2" />
  <img src="https://img.shields.io/badge/SwiftUI-blue?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Concurrency-Strict-2ea44f" alt="Strict Concurrency" />
  <img src="https://img.shields.io/badge/License-AGPL--3.0-blue" alt="AGPL-3.0" />
  <img src="https://img.shields.io/badge/v0.9.3.1-Active_Development-orange" alt="Active Development" />
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
    <td><img src="GUI/Docs/Preview2.png" alt="Main Interface" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>Favorites</em></td>
  </tr>
</table>


<table>
  <tr>
    <td><img src="GUI/Docs/Preview1.png" alt="Main Interface" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>History</em></td>
  </tr>
</table>


---

## Features

### Core

| Feature | Description |
|---------|-------------|
| **Dual Panels** | Two independent file panels with synchronized operations |
| **Tabbed Interface** | Multiple tabs per panel (⌘T open, ⌘W close, ⌘⇧]/[ switch); tab context menu; persistence between launches |
| **Finder-Style Table** | Sortable columns: Name, Size, Date, Permissions, Owner, Type |
| **Multi-Selection** | Cmd+Click toggle, Shift+Click range, Insert mark+next, pattern matching, Ctrl+A |
| **Group Operations** | Batch Cut/Copy/Compress/Share/Delete on marked files; group context menu |
| **Multi-File Drag & Drop** | Drag all marked files together; badge preview with count; Finder-compatible |
| **Find Files** | Advanced search: by name (wildcards), content, size, date — with archive search |
| **Archive VFS** | Open archives as virtual directories, navigate inside, auto-repack on exit |
| **Parent Directory** | `...` entry pinned to top of every panel, archive-aware navigation |
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
| `⌘O` | Open / Get Info | `⌘T` | New Tab |
| `⌘W` | Close Tab | `⌘⇧]`/`⌘⇧[` | Next/Prev Tab |
| `Cmd+Click` | Toggle file mark | `Shift+Click` | Range select |
| `Insert` | Toggle mark + next | `Ctrl+A` | Mark all files |
| `Num+` | Mark by pattern | `Num-` | Unmark by pattern |
| `Num*` | Invert marks | `⌘⌫` | Delete marked/selected |

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

### ⚠️ Download & Run (Pre-Built Binary)

> **The app is not notarized.** macOS Gatekeeper will block it on first launch.
> You **must** run this command after downloading:

```bash
xattr -cr ~/Downloads/MiMiNavigator.app
```

Then double-click `MiMiNavigator.app` as usual.

Alternatively: right-click the app → Open → click **Open** in the dialog.

**[Download latest release →](https://github.com/senatov/MiMiNavigator/releases/latest)**

---

### Build from Source

**Requirements:**
- macOS 15.4+ (Apple Silicon or Intel)
- Xcode (latest) with Swift 6.2
- Optional: `brew install swiftlint swift-format p7zip`

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
│   ├── States/
│   │   └── AppState/       # AppState (@Observable), SelectionManager,
│   │                       # MultiSelectionManager, MultiSelectionState,
│   │                       # ClickModifiers, StatePersistence
│   ├── Features/
│   │   ├── Tabs/           # TabItem, TabManager, TabBarView, TabItemView,
│   │   │                   # TabContextMenu
│   │   └── Panels/         # FilePanelView, FileRow, FileRowView,
│   │       │               # FileTableRowsView, SelectionStatusBar
│   │       └── FileTable/  # FileTableView (+Actions, +State, +Subviews),
│   │                       # TableHeaderView, TableKeyboardNavigation
│   ├── ContextMenu/
│   │   ├── ActionsEnums/   # FileAction, DirectoryAction, MultiSelectionAction,
│   │   │                   # PanelBackgroundAction
│   │   ├── Menus/          # FileContextMenu, DirectoryContextMenu,
│   │   │                   # MultiSelectionContextMenu, OpenWithSubmenu
│   │   ├── Dialogs/        # ConfirmationDialog, RenameDialog, PackDialog,
│   │   │                   # FileConflictDialog, BatchConfirmation/Progress
│   │   └── Services/       # ContextMenuCoordinator, FileActionsHandler,
│   │       │               # DirectoryActionsHandler, MultiSelectionActionsHandler,
│   │       │               # FileOperationExecutors
│   │       └── FileOperations/ # BatchOperationCoordinator, FileOperationsService
│   ├── Services/
│   │   ├── Archive/        # ArchiveManager (actor), Extractor, Repacker, FormatDetector
│   │   ├── Scanner/        # DualDirectoryScanner (actor), FileScanner
│   │   └── FileOperations/ # BasicFileOperations, FileDialogs, VSCodeIntegration
│   ├── FindFiles/          # Search UI, ViewModel, Coordinator
│   │   └── Engine/         # FindFilesEngine (actor), NameMatcher, ContentSearcher,
│   │                       # ArchiveSearcher, NativeZipReader
│   ├── DragDrop/           # DragDropManager, DragPreviewView (multi-file badge),
│   │                       # CustomFile+Transferable, FileTransferConfirmation
│   ├── Menus/              # TC-style glass menu bar
│   ├── BreadCrumbNav/      # Breadcrumb path bar with navigation
│   ├── HotKeys/            # Customizable keyboard shortcuts
│   ├── History/            # Navigation history popover
│   ├── Favorites/          # Favorites sidebar adapter (FavoritesKit bridge)
│   ├── Models/             # CustomFile, FileCache, SortKeysEnum
│   └── Config/             # DesignTokens, UserPreferences, AppConstants
├── Packages/
│   └── FavoritesKit/       # Reusable favorites module (.dylib)
└── Gui/Docs/               # Architecture docs, screenshots
```

### Key Patterns

| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState` — global app state, panels, archive states |
| `@Observable` + `@MainActor` | `MultiSelectionManager` — Cmd/Shift click, Insert mark, pattern match |
| `@Observable` + `@MainActor` | `TabManager` — per-panel tab collection, persistence, navigation |
| `@Observable` + `@MainActor` | `ContextMenuCoordinator` — singleton handling all context menu actions |
| `actor` | `DualDirectoryScanner` — thread-safe file scanning |
| `actor` | `ArchiveManager` — session lifecycle, dirty tracking, extraction, repacking |
| `AsyncStream` | `FindFilesEngine` — streaming search results with cancellation |
| `filesForOperation()` | Unified API: returns marked files if any, single selected file otherwise |
| `NSEvent.modifierFlags` | Detecting Cmd/Shift during SwiftUI gesture handlers |
| Security-Scoped Bookmarks | Persistent file access in sandboxed mode |
| Swift Package (dynamic) | `FavoritesKit` — extracted as reusable `.dylib` |

### Logging

Uses **SwiftyBeaver** with tags: `[FindEngine]` `[ArchiveSearcher]` `[Extractor]` `[Repacker]` `[FormatDetector]` `[SELECT-FLOW]` `[NAV]` `[DOUBLE-CLICK]`

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
- [x] Multi-selection: Cmd+Click, Shift+Click, Insert, pattern matching, Ctrl+A
- [x] Group context menu with batch operations
- [x] Multi-file drag & drop with badge preview
- [x] Batch-aware file actions (Cut/Copy/Delete/Compress/Share on marked files)
- [x] Total Commander style marking: dark red, semibold, enlarged font
- [x] Selection status bar (marked count + total size + disk free space)
- [x] Column width persistence 
- [x] Hotkey customization
- [x] Tabbed interface (multiple tabs per panel, context menu, persistence)
- [x] Archive Open → TC-style virtual directory (not Finder/Archive Utility) NOT READY YET!

### In Progress 🚧

- [ ] Batch rename for marked files
- [ ] Terminal integration at current path
- [ ] Custom themes and color schemes

### Planned 🎯
- [ ] Three-panel layout option
- [ ] FTP/SFTP connectivity
- [ ] Cloud storage (iCloud, Dropbox)
- [ ] Network filesystem (SMB)
- [ ] Advanced file comparison
- [ ] Plugin system
- [ ] App Store release

---

## Contributing

Contributions welcome! MiMiNavigator is a real-world SwiftUI project with clean architecture, strict Swift 6.2 concurrency, and plenty of room to grow.

### Good First Issues

Looking for a way to start? Here are areas where help is especially appreciated:

| Area | Difficulty | Description |
|------|-----------|-------------|
| **Batch Rename** | ⭐⭐ | Rename multiple marked files with pattern (e.g. `Photo_{N}.jpg`) |
| **File Preview** | ⭐⭐ | Quick Look panel for selected file (QLPreviewPanel integration) |
| **Themes** | ⭐⭐ | Dark/light/custom color schemes with persistence |
| **Localization** | ⭐ | Translate UI strings (German and Russian already done) |
| **Unit Tests** | ⭐⭐ | Tests for MultiSelectionManager, FileOperations, ArchiveManager |
| **FTP/SFTP** | ⭐⭐⭐ | Remote file system panel via Network framework |
| **Performance** | ⭐⭐ | Profile and optimize for directories with 10k+ files |

### How to Contribute

1. Fork the repo and create a feature branch
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) for code style and commit guidelines
3. Build and test locally (`⌘R` in Xcode)
4. Open a PR with a clear description and screenshots for UI changes

### Why Contribute?

- **Learn SwiftUI** on a real dual-panel file manager (not a todo app)
- **Swift 6.2 concurrency** — actors, async/await, `@Observable`, strict Sendable
- **macOS-native** development — NSWorkspace, security-scoped bookmarks, Quick Look, AppleScript
- **Clean architecture** — modular structure, no file over 400 lines, extensive logging
- Friendly maintainer who reviews PRs quickly

> I openly acknowledge using AI assistants for architecture discussions and code review. This README was crafted with care for both humans and crawlers.

---

## License

[AGPL-3.0](LICENSE) — Iakov Senatov

<p align="center">
  <a href="https://www.linkedin.com/in/iakov-senatov-07060765"><img src="https://img.shields.io/badge/LinkedIn-Iakov_Senatov-0077B5?logo=linkedin&logoColor=white" alt="LinkedIn"></a>
  <a href="https://github.com/senatov"><img src="https://img.shields.io/badge/GitHub-senatov-181717?logo=github&logoColor=white" alt="GitHub"></a>
</p>

<p align="center"><sub>Made with ❤️ for macOS · Building the future of file management, one commit at a time</sub></p>
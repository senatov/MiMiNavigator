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
  <img src="https://img.shields.io/badge/SwiftUI-Context_Menus-blue?logo=swift&logoColor=white" alt="SwiftUI Context Menus" />
  <img src="https://img.shields.io/badge/Concurrency-Strict-2ea44f" alt="Strict Concurrency" />
  <img src="https://img.shields.io/badge/SFTP-Citadel-0a7bbb" alt="SFTP via Citadel" />
  <img src="https://img.shields.io/badge/Archives-50%2B_Formats-6f42c1" alt="50+ archive formats" />
  <img src="https://img.shields.io/badge/Media-Preview_%26_Conversion_Placeholders-ff8c00" alt="Media preview and conversion placeholders" />
  <img src="https://img.shields.io/badge/License-AGPL--3.0-blue" alt="AGPL-3.0" />
  <img src="https://img.shields.io/badge/v0.9.8.5-Active_Development-orange" alt="Active Development" />
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#screenshots">Screenshots</a> ·
  <a href="#getting-started">Getting Started</a> ·
  <a href="#architecture">Architecture</a> ·
  <a href="#archive-support">Archive Support</a> ·
  <a href="GUI/Docs/PLUGIN_BLUE_PAPER.md">Plugin Blue Paper</a> ·
  <a href="#roadmap">Roadmap</a>
</p>

---

> ** 🔨 Under active development 🔨.
** APIs and UI may change without notice.



## Recent Changes (v0.9.8.6 — May 2026)

- **Geo-tagged photo badges** — images with GPS metadata show a compact orange globe badge directly on the file icon.
- **Media Info GPS links** — Apple Maps, Google Maps, and OpenStreetMap links now appear near the top of the media information panel.
- **Breadcrumb polish** — local paths show the filesystem root segment and Copy path uses the real filesystem path.
- **Package split** — scanner and archive internals now live in `ScannerKit` and `ArchiveKit`, reducing duplicate app-side code.
- **Mounted volume scanning** — local and external volumes use leaner metadata prefetching for faster, safer listings.
- **File operation progress** — many-small-file copy operations now report live byte progress with the hybrid stream-copy path.
- **Archive compatibility** — AES ZIP extraction and ArchiveKit public API boundaries were fixed for app UI usage.
- **Remote and dialog polish** — SFTP hidden-file filtering, connection auth handling, history/favorites dialogs, and keyboard focus were tightened.
- **Release metadata** — version `0.9.8.6` and build `117` updated for the notarized DMG release.

---

## What is MiMiNavigator?

MiMiNavigator is a dual-panel file manager inspired by **Total Commander** and **Norton Commander**, reimagined with native macOS technologies. It combines the efficiency of classic two-panel navigation with modern SwiftUI, Swift concurrency (actors, async/await), and macOS 26 liquid-glass design language.

**Why another file manager?**
- Finder lacks dual-panel workflow → MiMiNavigator gives you two panels side by side
- Total Commander doesn't exist on macOS → MiMiNavigator brings TC-style menus and hotkeys
- Built as a SwiftUI showcase → clean architecture, strict concurrency, modular packages

---

## Screenshots

[Watch demo](https://www.youtube.com/watch?v=rgPYIAMx0p0)


<table>
  <tr>
    <td><img src="GUI/Docs/Preview0.png" alt="Main Interface" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>Preview</em></td>
  </tr>
</table>


<table>
  <tr>
    <td><img src="GUI/Docs/Preview2.png" alt="Main Interface" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><em>History</em></td>
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
| **List & Thumbnail Views** | Toggle per panel via toolbar; thumbnail size 16–900 pt via inline status-bar slider |
| **Finder-Style Table** | Sortable columns: Name, Size, Date, Permissions, Owner, Type |
| **Multi-Selection** | Cmd+Click toggle, Shift+Click range, Insert mark+next, pattern matching, Ctrl+A |
| **Group Operations** | Batch Cut/Copy/Compress/Share/Delete on marked files; group context menu |
| **Multi-File Drag & Drop** | Drag all marked files together; badge preview with count; Finder-compatible; works in both list and thumbnail views |
| **Media Actions** | Native media info command plus a new placeholder `Convert Media 􀍓 􁔘...` entry for convertible media files (currently disabled, planned for future conversion workflows) |
| **Find Files** | Advanced search: by name (wildcards), content, size, date — with archive search |
| **Archive VFS** | Open archives as virtual directories, navigate inside, auto-repack on exit |
| **Parent Directory** | `...` entry pinned to top of every panel, archive-aware navigation |
| **Navigation History** | Per-panel history with quick-jump popover |
| **Breadcrumb Nav** | Click-to-navigate path bar with arrowshape back/forward/up controls and autocomplete popup (ESC/click-outside dismiss, slide animation) |
| **Favorites Sidebar** | Quick access to bookmarked locations (FavoritesKit package) |
| **Real-time Updates** | Automatic refresh on file system changes |
| **FTP/SFTP** | Remote file browsing via curl (FTP) and Citadel/NIOSSH (SFTP) |
| **Network Neighborhood** | SMB/AFP share discovery, mounting, and browsing across LAN |
| **Connect to Server** | Saved server bookmarks with keychain passwords, session reuse, disconnect |

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
- Context menus reorganized around stable submenu groups instead of fragile Option-only branches
- Pixel-perfect Retina rendering via `backingScaleFactor`
- Sticky column headers, zebra-striped rows with themed colors (active/inactive panel)
- Zebra background fill extends below file rows to fill empty panel space
- Animated toolbar buttons, NSVisualEffectView popover for autocomplete
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

### ⬇️ Download & Run (Pre-Built Binary)

> **The app is notarized by Apple.** Starting from v0.9.7.4, macOS Gatekeeper will allow it to run without workarounds.

1. Download the DMG from the link below
2. Open the DMG, drag MiMiNavigator to Applications
3. Launch MiMiNavigator from Applications

> For older releases (before v0.9.7.4) you may need to run:
> ```bash
> xattr -cr ~/Downloads/MiMiNavigator.app
> ```

**[Download latest release →](https://github.com/senatov/MiMiNavigator/releases/latest)**

---

### Build from Source
**Requirements:**
- macOS 26+ (Apple Silicon)
- Xcode (latest) with Swift 6.2
- Optional: `brew install swiftlint swift-format p7zip`

```bash
git clone --recurse-submodules https://github.com/senatov/MiMiNavigator.git
cd MiMiNavigator
zsh Scripts/stamp_version.zsh   # sync version from git tag
open MiMiNavigator.xcodeproj
# ⌘R to build and run
```

Or via command line:

```bash
zsh Scripts/stamp_version.zsh
xcodebuild -scheme MiMiNavigator -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

**Production Build:**
```bash
xcodebuild -project MiMiNavigator.xcodeproj -scheme MiMiNavigator \
  -configuration Release -derivedDataPath /tmp/mimi_build build CODE_SIGNING_ALLOWED=YES
```
Binary output: `/tmp/mimi_build/Build/Products/Release/MiMiNavigator.app`

---

## Architecture

```
MiMiNavigator/
├── GUI/Sources/
│   ├── App/                # Entry point, AppLogger, toolbar
│   ├── AppDelegates/       # NSApplicationDelegate
│   ├── States/
│   │   ├── AppState/       # AppState (@Observable), SelectionManager,
│   │   │                   # MultiSelectionManager, StatePersistence,
│   │   │                   # FileListSnapshot, FileSortingService
│   │   ├── Commands/       # AppCommands (menu bindings)
│   │   └── History/        # PanelNavigationHistory, SelectionsHistory,
│   │                       # HistoryEntry, FileSnapshot
│   ├── Features/
│   │   ├── Tabs/           # TabItem, TabManager, TabBarView, TabItemView,
│   │   │                   # TabContextMenu
│   │   ├── Panels/         # FilePanelView, FileRow, FileRowView,
│   │   │   │               # FileTableRowsView, SelectionStatusBar,
│   │   │   │               # AliasIconComposer, PanelDividerView
│   │   │   ├── FileTable/  # FileTableView (+Actions, +State),
│   │   │   │               # TableHeaderView, TableKeyboardNavigation,
│   │   │   │               # ColumnLayoutModel, ResizableDivider
│   │   │   └── Filter/     # PanelFilterBar, PanelFilterHistory
│   │   ├── Network/        # NetworkNeighborhoodView, NetworkHost,
│   │   │                   # NetworkMountService, NetworkDeviceFingerprinter,
│   │   │                   # FritzBoxDiscovery, WebUIProber
│   │   ├── ConnectToServer/# ConnectToServerView, RemoteFileProvider,
│   │   │                   # RemoteConnectionManager, RemoteServerStore
│   │   └── Popups/         # FileInfoPopupController, InfoPopupController, ConnectErrorPopupController, FileInfoPopupController,
│   │                       # PopupEventMonitors (@MainActor, deinit-safe monitors)
│   ├── ContextMenu/
│   │   ├── ActionsEnums/   # FileAction, DirectoryAction, MultiSelectionAction,
│   │   │                   # PanelBackgroundAction
│   │   ├── Menus/          # FileContextMenu, DirectoryContextMenu,
│   │   │                   # MultiSelectionContextMenu, OpenWithSubmenu,
│   │   │                   # submenu-based advanced operations
│   │   ├── Dialogs/        # ConfirmationDialog, RenameDialog, PackDialog,
│   │   │   │               # BatchConfirmation/Progress, CreateLinkDialog,
│   │   │   │               # ContextMenuDialogModifier+Builder
│   │   │   └── FileConflict/  # FileConflictDialog, ConflictResolution
│   │   └── Services/       # CntMenuCoord, ClipboardManager,
│   │       │               # CompressService, QuickLookService
│   │       ├── Coordinator/   # CntMenuCoord+FileActions,
│   │       │                  # +DirectoryActions, +BackgroundActions,
│   │       │                  # +MultiSelectionActions, ActiveDialog
│   │       └── FileOperations/ # FileOperationsService (core: copy/move/conflict),
│   │                          # FileOpsService+Delete, +Rename, +SymLink,
│   │                          # BatchOperationCoordinator, DirectorySizeCalculator
│   ├── Services/
│   │   ├── Archive/        # ArchiveManager (actor), ArchiveExtractor,
│   │   │                   # ArchiveRepacker, ArchiveFormatDetector,
│   │   │                   # ArchiveNavigationState, ArchivePasswordStore
│   │   ├── Scanner/        # DualDirectoryScanner (actor), FileScanner,
│   │   │                   # FSEventsDirectoryWatcher
│   │   ├── FileOperations/ # BasicFileOperations, FileDialogs, VSCodeIntegration
│   │   ├── ErrorAlertService.swift  # show / confirm / promptPassword helpers
│   │   └── Diagnostics/    # SpinnerWatchdog
│   ├── FindFiles/          # FindFilesViewModel, FindFilesCoordinator,
│   │   │                   # FindFilesWindowContent, SearchHistoryManager
│   │   └── Engine/         # FindFilesEngine (actor), FindFilesNameMatcher,
│   │                       # FindFilesContentSearcher, FindFilesArchiveSearcher,
│   │                       # NativeZipReader, FindFilesResultBuffer
│   ├── DragDrop/           # DragDropManager, DragPreviewView,
│   │                       # FileTransferConfirmationDialog
│   ├── Menus/              # TC-style glass menu bar, MenuCategory, MenuItem
│   ├── BreadCrumbNav/      # BreadCrumbView, PathAutoCompleteField
│   ├── HotKeys/            # HotKeyStore, HotKeySettingsView, HotKeyRecorderView,
│   │                       # ShortcutConflictValidator
│   ├── History/            # HistoryRow, HistoryWindowContent
│   ├── Favorites/          # FavoritesNavigationAdapter, BookmarkStore
│   ├── Settings/           # SettingsWindowView, SettingsColorsPane,
│   │                       # DiffToolRegistry, SettingsPermissionsPane
│   ├── SplitLine/          # OrangeSplitView, SplitContainer, DividerAppearance
│   ├── Toolbar/            # ToolbarStore, ToolbarCustomizeView
│   ├── Config/             # DesignTokens, UserPreferences, AppConstants,
│   │                       # InterfaceScaleStore, PreferenceKeys
│   └── Localization/       # L10n.swift
├── Packages/               # git submodule → github.com/senatov/MiMiKits (private)
│   ├── ArchiveKit/         # Archive format support module
│   ├── FavoritesKit/       # Reusable favorites module (.dylib)
│   ├── FileModelKit/       # CustomFile model and utilities
│   ├── LogKit/             # Centralized logging (SwiftyBeaver)
│   ├── NetworkKit/         # Network neighborhood discovery (SMB/AFP)
│   └── ScannerKit/         # File scanning utilities
└── GUI/Docs/               # Architecture docs, screenshots

```

### Key Patterns

| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState` — global app state, panels, archive states |
| `@Observable` + `@MainActor` | `MultiSelectionManager` — Cmd/Shift click, Insert mark, pattern match |
| `@Observable` + `@MainActor` | `TabManager` — per-panel tab collection, persistence, navigation |
| `@Observable` + `@MainActor` | `CntMenuCoord` — singleton handling all context menu actions |
| `actor` | `DualDirectoryScanner` — thread-safe file scanning |
| `actor` | `ArchiveManager` — session lifecycle, dirty tracking, extraction, repacking |
| `AsyncStream` | `FindFilesEngine` — streaming search results with cancellation |
| `PopupEventMonitors` | `@MainActor` class, owns NSEvent monitors, `nonisolated(unsafe)` only in `deinit` |
| `ErrorAlertService` | `@MainActor enum`, replaces scattered `NSAlert.runModal()` calls |
| `filesForOperation()` | Unified API: returns marked files if any, single selected file otherwise |
| `NSEvent.modifierFlags` | Detecting Cmd/Shift during SwiftUI gesture handlers |
| Security-Scoped Bookmarks | Persistent file access in sandboxed mode |
| Swift Package (dynamic) | `FavoritesKit` — extracted as reusable `.dylib` |

### Logging

Uses **SwiftyBeaver** with tags: `[FindEngine]` `[ArchiveSearcher]` `[Extractor]` `[Repacker]` `[FormatDetector]` `[SELECT-FLOW]` `[NAV]` `[DOUBLE-CLICK]`

Log files:
- Sandboxed: `~/Library/Containers/Senatov.MiMiNavigator/Data/Library/Application Support/MiMiNavigator/Logs/MiMiNavigator.log`
- External (dev): `/private/tmp/MiMiNavigator.log`

---

## Cloud Storage

MiMiNavigator **auto-discovers** cloud drives mounted on your Mac. Any provider that syncs through `~/Library/CloudStorage` appears automatically in the sidebar under **Cloud Drives**.

| Provider | How it appears |
|----------|---------------|
| Google Drive | Install [Google Drive for Desktop](https://www.google.com/drive/download/) → appears automatically; shared uploads appear under `My Drive/Public` after sync |
| OneDrive | Install [OneDrive for Mac](https://www.microsoft.com/en-us/microsoft-365/onedrive/download) → appears automatically |
| Dropbox | Install [Dropbox for Mac](https://www.dropbox.com/install) → appears automatically |
| Proton Drive | Install [Proton Drive for Mac](https://proton.me/drive/download) → appears automatically |
| iCloud Drive | Built into macOS → appears automatically |
| Any other provider | If it mounts to `~/Library/CloudStorage`, it will be detected |

### Google Drive Share Links

File and directory R-Menu includes **Copy Share Link** for Google Drive publishing:

1. MiMiNavigator uploads the selected item to a `Public` folder in Google Drive.
2. It creates an external Google Drive link with **View only** or **Allow editing** permission.
3. The link is copied to the clipboard.
4. The first use opens Google OAuth in the browser. After consent, the refresh token is stored in macOS Keychain and later share-link actions run without opening the browser again unless access is revoked.

Google Drive app credentials are application credentials, not user credentials. A development build can bundle `GUI/Resources/google_drive_oauth.json`; this file is intentionally git-ignored. Use `GUI/Resources/google_drive_oauth.example.json` as the template and never commit a real Google OAuth client secret. User access and refresh tokens are never written to project files.

When Google Drive for Desktop syncs the `Public` folder locally, MiMiNavigator shows it as **Google Drive Public** in the sidebar.

**For power users:** [rclone](https://rclone.org/) can mount virtually any cloud provider (S3, B2, MEGA, etc.) as a local FUSE filesystem. Once mounted, it appears in `/Volumes` and is browsable in MiMiNavigator.

> MiMiNavigator is primarily a filesystem browser. Google Drive share-link generation is the current exception: it uses Google OAuth only to upload selected items to `Public` and create shareable links.

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
- [x] Multi-file drag & drop with badge preview (list and thumbnail modes)
- [x] Batch-aware file actions (Cut/Copy/Delete/Compress/Share on marked files)
- [x] Total Commander style marking: dark red, .light, enlarged font
- [x] Selection status bar (marked count + total size + disk free space + inline slider)
- [x] Thumbnail grid view per panel (16–900 pt, QL thumbnails, context menu, drag-drop)
- [x] Open With LRU per file extension (max 5, "Other..." picks persisted)
- [x] Column width persistence
- [x] Hotkey customization
- [x] Tabbed interface (multiple tabs per panel, context menu, persistence)
- [x] Archive Open → TC-style virtual directory (not Finder/Archive Utility)
- [ ] Media conversion dialog and scripts for `Convert Media...`
- [x] Zebra-striped background fill for empty panel space
- [x] Autocomplete popup: click-outside / ESC dismiss, slide animation, NSVisualEffectView
- [x] FileOperationsService split into modular extensions (Delete, Rename, SymLink)
- [x] HIGAlertDialog extracted to own file
- [x] Firmlink handling for `/tmp`, `/var`, `/etc` in scanner and file operations
- [x] Rename: panel tracking, scan cooldown fix, firmlink path resolution
- [x] Version auto-sync from git tag via `Scripts/stamp_version.zsh`
- [x] Google Drive share-link publishing to `Public` with Keychain-backed OAuth

### In Progress 🚧

- [ ] Batch rename for marked files
- [ ] Terminal integration at current path
- [ ] Custom themes and color schemes
- [ ] Scroll-to-selection after rename/create operations

### Planned 🎯
- [ ] Three-panel layout option
- [x] FTP/SFTP connectivity (Citadel SFTP + curl-based FTP)
- [x] Network filesystem (SMB/AFP mount, Network Neighborhood discovery)
- [ ] More cloud provider share-link APIs beyond Google Drive
- [ ] Advanced file comparison
- [ ] Plugin system — see [Plugin Development Blue Paper](GUI/Docs/PLUGIN_BLUE_PAPER.md)
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


---


## Third-Party Libraries and Licenses

Sincere thanks to the open-source community:

| Author | Project | License | Why it matters |
|--------|---------|---------|----------------|
| Sebastian Kreutzberger | [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) | MIT | Clean, fast, low-friction logging that simply works |
| Joannis Orlandos | [Citadel](https://github.com/orlandos-nl/Citadel) | MIT | An excellent SSH/SFTP library that fills an important gap not covered by SwiftNIO SSH |
| Thomas Zoechling | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | MIT | A strong example of clean Swift API design and a likely future dependency |
| The Nmap Project | [nmap](https://nmap.org) | GPLv2 | The gold standard in network diagnostics, invaluable during LAN discovery development |
| Apple | SwiftNIO, SwiftUI, kqueue, NetServiceBrowser | Apple licenses | Making macOS-native development a genuine pleasure |
| Omar Albeik | [VLC](https://github.com/omaralbeik/VLC) | MIT | Swift package wrapper used for extended media playback integration |
| VideoLAN | libVLC / VLC | LGPL v2 or later | Underlying playback engine for media formats not reliably handled by the native macOS media stack |

Full third-party license texts and notices should also be provided in the application bundle, About/Credits section, or in a dedicated `Licenses` / `ThirdPartyNotices` folder.

Special thanks to **Anthropic / Claude** for pair-programming support throughout this project, including architecture decisions, refactoring, debugging, and documentation.

## Acknowledgements

**MiMiNavigator** is developed by **Iakov Senatov** -- Diplom-Ingenieur (Chemical Process Engineering), 35 years of programming experience.






## License

[AGPL-3.0](LICENSE) — Iakov Senatov

<p align="center">
  <a href="https://www.linkedin.com/in/iakov-senatov-07060765"><img src="https://img.shields.io/badge/LinkedIn-Iakov_Senatov-0077B5?logo=linkedin&logoColor=white" alt="LinkedIn"></a>
  <a href="https://github.com/senatov"><img src="https://img.shields.io/badge/GitHub-senatov-181717?logo=github&logoColor=white" alt="GitHub"></a>
</p>

<p align="center"><sub>Made with ❤️ for macOS · Building the future of file management, one commit at a time</sub></p>

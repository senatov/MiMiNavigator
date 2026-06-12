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
  <img src="https://img.shields.io/badge/Media-Preview_%26_Conversion-ff8c00" alt="Media preview and conversion" />
  <img src="https://img.shields.io/badge/License-AGPL--3.0-blue" alt="AGPL-3.0" />
  <a href="https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.9.5.2"><img src="https://img.shields.io/badge/release-v0.9.9.5.2-orange" alt="Release v0.9.9.5.2" /></a>
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

> **🔨 Under active development 🔨**  
> APIs and UI may change without notice.



## Recent Changes (v0.9.9.5.2 - June 2026)

- **Bottom panel tabs** — tabs now share the status strip with wider glass styling, restored paths, distinct active-state colors, and compact hover details.
- **Parent navigation** — the parent-directory strip is a full-width glass control with reliable hover tracking, animated feedback, and a dedicated navigation cursor.
- **Selection fallback** — archive and directory navigation preserves a valid selection or selects the first real row when no saved match exists.
- **Finder-style Option menus** — context menus reveal native alternate file and folder operations live while Option is held.
- **Get Info coverage** — Get Info is available for files, directories, and multiple selections.
- **Progress feedback** — fast atomic operations no longer display or reuse stale archive progress panels.
- **Table headers** — column labels have corrected height and vertical alignment.
- **Build metadata** — release version is `0.9.9.5.2`, build `123`.

## Previous Changes

- **v0.9.9.5.1** — breadcrumb hover lens clarity and sharper enlarged path text.
- **v0.9.9.5** — drag-and-drop file operation stability, breadcrumb truncation polish, managed mount cleanup, progress panel hardening, and file context menu cleanup.
- **v0.9.9.4** — media conversion presets, External Tool Doctor, FFmpeg/gifski checks, IntelliJ IDEA diff detection, and shared repair flow for archive tools.
- **v0.9.9.3** — unified List/Preview/Tree view behavior, Preview drag-and-drop reliability, Tree view mode, and periodic configuration autosave.

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

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
| **Media Actions** | Native media info command plus `Convert Media 􀍓 􁔘...` presets for video, GIF, audio, and image files |
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

**Extraction chain:** `/usr/bin/unzip` → `/usr/bin/tar` (libarchive) → `7z` (fallback). Install archive tools with `brew install unar p7zip`.

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

**[Download MiMiNavigator v0.9.9.5.2 ->](https://github.com/senatov/MiMiNavigator/releases/tag/v0.9.9.5.2)**
**[All releases →](https://github.com/senatov/MiMiNavigator/releases)**

---

### Build from Source
**Requirements:**
- macOS 26+ (Apple Silicon)
- Xcode (latest) with Swift 6.2
- Optional: `brew install swiftlint swift-format unar p7zip`

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
│   ├── RenameKit/          # F2 inline rename with undo support
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

### Cloud Share Links

File and directory R-Menu includes **Share+Link** for Google Drive and Dropbox publishing:

1. MiMiNavigator detects the mounted cloud providers and asks which provider to use when both are available.
2. Google Drive uploads to `My Drive/Public` and supports **View only** or **Allow editing**.
3. Dropbox copies the item to `Public`, waits for sync, and creates a view-only shared link.
4. The provider URL is shortened to `https://spoo.me/mimiNavi_<14 random Base62 characters>` and copied to the clipboard.
5. The first use opens provider OAuth in the browser. Refresh tokens are stored in macOS Keychain.

Google Drive app credentials are application credentials, not user credentials. A development build can bundle `GUI/Resources/google_drive_oauth.json`; this file is intentionally git-ignored. Use `GUI/Resources/google_drive_oauth.example.json` as the template and never commit a real Google OAuth client secret. User access and refresh tokens are never written to project files.

Dropbox authorization uses PKCE and does not embed an app secret. Alias generation uses the shared `CloudLinkShortener` implementation for both providers; the long random suffix prevents predictable links and makes collisions impractical.

When a cloud desktop client syncs the `Public` folder locally, MiMiNavigator exposes the provider folder in the sidebar.

**For power users:** [rclone](https://rclone.org/) can mount virtually any cloud provider (S3, B2, MEGA, etc.) as a local FUSE filesystem. Once mounted, it appears in `/Volumes` and is browsable in MiMiNavigator.

> MiMiNavigator is primarily a filesystem browser. Google Drive and Dropbox Share+Link are narrow API integrations used only to publish selected items and create shareable links.

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
- [x] Media conversion dialog and scripts for `Convert Media...`
- [x] Zebra-striped background fill for empty panel space
- [x] Autocomplete popup: click-outside / ESC dismiss, slide animation, NSVisualEffectView
- [x] FileOperationsService split into modular extensions (Delete, Rename, SymLink)
- [x] HIGAlertDialog extracted to own file
- [x] Firmlink handling for `/tmp`, `/var`, `/etc` in scanner and file operations
- [x] Rename: panel tracking, scan cooldown fix, firmlink path resolution
- [x] Version auto-sync from git tag via `Scripts/stamp_version.zsh`
- [x] Google Drive share-link publishing to `Public` with Keychain-backed OAuth
- [x] Dropbox Share+Link with PKCE, sync-aware publishing, and branded random aliases

### In Progress 🚧

- [ ] Batch rename for marked files
- [ ] Terminal integration at current path
- [ ] Custom themes and color schemes
- [ ] Scroll-to-selection after rename/create operations

### Planned 🎯
- [ ] Three-panel layout option
- [x] FTP/SFTP connectivity (Citadel SFTP + curl-based FTP)
- [x] Network filesystem (SMB/AFP mount, Network Neighborhood discovery)
- [ ] More cloud provider share-link APIs beyond Google Drive and Dropbox
- [ ] Advanced file comparison
- [ ] Plugin system — see [Plugin Development Blue Paper](GUI/Docs/PLUGIN_BLUE_PAPER.md)
- [ ] App Store release

### Competitive Feature Gaps

These items are based on features that competing macOS file managers use as clear selling points. They should guide future work toward high-value file-manager workflows before adding unrelated experimental features.

| Priority | Feature | Why it matters |
|----------|---------|----------------|
| **P0** | **Batch Rename with live preview and undo** | A core power-user workflow. Rule stacking, before/after preview, and one-step rollback make it safer than simple multi-file rename. |
| **P0** | **Persistent Preview Pane** | A permanent panel for images, PDFs, media, Markdown, source code, text, and hex previews is more useful than a temporary Quick Look popup during heavy browsing. |
| **P0** | **Folder Sync / Directory Compare** | Two-pane managers are naturally suited for local-to-local, local-to-remote, and remote-to-remote comparison with one-way/two-way sync and conflict handling. |
| **P1** | **Command Bar / Quick Open (`⌘K`)** | A fast command surface for paths, favorites, menu actions, file operations, saved presets, and recently used commands reduces menu hunting without weakening keyboard-first workflows. |
| **P1** | **Workspaces** | Save and restore complete layouts: panes, tabs, paths, sort order, view mode, splitter position, and scroll position. Useful for repeated project, media, server, and archive workflows. |
| **P1** | **Git status badges and basic Git actions** | Developers benefit from inline repository state: modified/untracked/ignored badges, branch display, and focused actions such as open in terminal or reveal changed files. |
| **P1** | **First-class remote/cloud backends** | FTP/SFTP and mounted cloud folders are already present, but competitors sell direct S3, B2, WebDAV, Dropbox, OneDrive, Google Drive, SMB, AFP, and NFS workflows. |
| **P2** | **Duplicate Finder** | Exact duplicates via hashing and near-duplicate images via perceptual hashing turn file cleanup into a built-in workflow instead of a separate utility. |
| **P2** | **App Deleter / leftovers cleanup** | macOS users value safe app removal with related files from Application Support, Caches, Preferences, and launch agents clearly shown before deletion. |
| **P2** | **Better system integration** | Finder services, URL handlers, share extensions, "Open in MiMiNavigator", and optional default-file-viewer behavior make the app feel like part of macOS instead of a standalone island. |

Recommended implementation order:

1. Batch Rename with live preview and undo.
2. Persistent Preview Pane.
3. Folder Sync / Directory Compare.
4. Command Bar / Quick Open.
5. Workspaces.
6. Git status badges.
7. Direct WebDAV/S3/B2 support or an rclone-first backend.

Avoid prioritizing AI, Bluetooth, dashboards, or generic device-control features until the core file-manager workflows above feel complete.

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
| **Performance** | ⭐⭐ | ~~Profile and optimize for directories with 10k+ files~~ **Done in v0.9.8.8** — 19k files: 231s→13s |

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
| The Nmap Project | [nmap](https://nmap.org) | GPLv2 | The gold standard in network diagnostics, invaluable during LAN discovery development |
| FFmpeg contributors | [FFmpeg](https://ffmpeg.org/legal.html) | LGPL/GPL depending on build | External command-line backend for media conversion presets |
| Apple | [VideoToolbox](https://developer.apple.com/documentation/videotoolbox) | Apple SDK | Hardware H.264/HEVC encode presets on macOS |
| Kornel Lesinski | [gifski](https://gif.ski) | AGPL/commercial | Optional high-quality animated GIF encoder |
| JetBrains | [IntelliJ IDEA](https://www.jetbrains.com/help/idea/comparing-files-and-folders.html) | Community/free or commercial | Optional external file and directory diff viewer via `idea diff` |
| Apple | SwiftNIO, SwiftUI, kqueue, NetServiceBrowser | Apple licenses | Making macOS-native development a genuine pleasure |

Full third-party license texts and notices should also be provided in the application bundle, About/Credits section, or in a dedicated `Licenses` / `ThirdPartyNotices` folder.

## Acknowledgements

**MiMiNavigator** is developed by **Iakov Senatov** -- Diplom-Ingenieur (Chemical Process Engineering), 35 years of programming experience.

## License

[AGPL-3.0](LICENSE) — Iakov Senatov

<p align="center">
  <a href="https://www.linkedin.com/in/iakov-senatov-07060765"><img src="https://img.shields.io/badge/LinkedIn-Iakov_Senatov-0077B5?logo=linkedin&logoColor=white" alt="LinkedIn"></a>
  <a href="https://github.com/senatov"><img src="https://img.shields.io/badge/GitHub-senatov-181717?logo=github&logoColor=white" alt="GitHub"></a>
</p>

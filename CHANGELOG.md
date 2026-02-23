# Changelog

All notable changes to MiMiNavigator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — 2026-02-23

### Changed
- **Packages/ extracted to private git submodule** — `NetworkKit`, `FavoritesKit`, `LogKit` moved to private repo `github.com/senatov/MiMiKits`, connected back as git submodule at `Packages/`. Xcode project unchanged, full debug/edit/commit workflow preserved.

### Added
- **Top menu — real actions wired** (was all stubs before)
  - **Files**: Pack marked files via `ContextMenuCoordinator`, Quit via `NSApplication`
  - **Mark**: Select All, Unselect All, Invert, Select by Pattern, Unselect by Pattern, Select Same Extension — all via `AppState`/`MultiSelectionManager`
  - **Commands**: Find Files (`FindFilesCoordinator`), Open in Terminal, Open in Finder, Toggle Panel Focus
  - **Show**: Refresh Panel, Show/Hide Hidden Files (`UserPreferences`)
  - **Configuration**: Keyboard Shortcuts (`HotKeySettingsCoordinator`)
  - **Start**: New Tab, Duplicate Tab, Close Tab, Next Tab, Previous Tab — via `TabManager`
  - **Help**: Keyboard Shortcuts, Visit GitHub; stubs for unimplemented items show `NSAlert`
  - `AppStateProvider` — `@MainActor` weak singleton bridge so menu closures reach live `AppState`

- **Inline panel filter bar** — real-time file filtering in status bar
  - SwiftUI `TextField` with system `controlBackgroundColor` background (HIG-compliant)
  - Blue focus ring `1.5pt` on active, thin `0.5pt` at rest
  - `×` clear button appears/disappears with animation
  - `chevron.down` opens history popover — per-item `×` delete button, no duplicates
  - Persistent history per panel (max 16 entries) via `UserDefaults`
  - Real-time filter: every keystroke filters `CustomFile.nameStr` (case-insensitive)
  - `PanelFilterHistory` — `@MainActor ObservableObject`, `add()` deduplicates automatically
  - Integrated into `SelectionStatusBar` between disk space and item count labels

### Changed
- **CI workflow** — migrated from broken `macos-latest` + `Xcode_16.1` to `macos-26` + `Xcode 26.2`
  - Switched to `xcbeautify --renderer github-actions` for annotated build output
  - Added 15-minute timeout on `xcodebuild test` (known Xcode 26 hang issue)
  - Added GitHub Actions Job Summary step

- **UI dividers** — panel and column separator colors:
  - Passive: pale orange `rgba(255,179,102, 0.45)`, `0.5–1pt`
  - Hover: pale blue `rgba(115,184,255, 0.85)`, `1–2pt`
  - Drag: red-orange `rgba(242,97,26, 0.90)`, `1–3pt`

### Removed
- Panel focus border (orange glow) — removed from `FileTableView+Subviews` and `FilePanelView`

---

## [0.9.3] - 2026-02-14

### Added
- **Compact progress dialog** for file operations (copy/move/delete/pack)
  - Shows operation title, current file name, N/M counter, native progress bar, Stop button
  - Auto-closes on completion — no OK button needed
  - Cancellation support via Stop button
- **Progress bar in Find Files dialog**
  - Linear progress bar at bottom during search
  - Shows currently scanned directory path (truncated from head)
  - Stats: dirs/files/archives/elapsed time
- **ComboBox with history** for Find Files fields
  - Search for, Search in, Find text — all NSComboBox with dropdown history
  - Up to 32 values per field, no duplicates, newest first
  - Persisted in UserDefaults between sessions
  - Auto-complete, Enter-to-search support
- **Word-Einstellungen visual style** for Find Files dialog
  - Bold section headers with colored SF Symbol icons
  - Colored icons per field (orange doc, blue folder, purple text search)
  - Options with colored toggle icons (indigo, teal, blue, brown)
  - Subtle blue borders on input fields and section containers

### Fixed
- **Drag-drop multi-file selection loss** — internal drags now read from DragDropManager directly
- **Garbled non-ASCII filenames** in Move/Copy dialog (Cyrillic, emoji)
- **Exclusive panel marking** — marking files on one panel clears marks on the other

### Changed
- File operations (copy/move/delete/pack) show progress dialog during operation
- Silent auto-close after completion (no completion confirmation dialog)

## [0.9.2] - 2026-02-14

### Added
- **Tab Support (Stage 1 — Data Model)**
  - `TabItem` model: path, display name (macOS FileManager.displayName), archive state
  - macOS-standard middle truncation for tab names
  - `TabManager` per panel: add, close, select, next/prev (wraps around)
  - Minimum one tab guaranteed per panel (last tab cannot be closed)
  - Max 32 tabs per panel limit
  - New tab inserted after active tab
  - Tab persistence via UserDefaults (save/restore between launches)
  - Path validation on restore — stale tabs auto-removed
  - Factory methods: `TabItem.directory()`, `TabItem.archive()`
  - `AppState` integration: `leftTabManager`, `rightTabManager`, `tabManager(for:)`
  - `PreferenceKeys` extended: `leftTabs`, `rightTabs`, `leftActiveTabID`, `rightActiveTabID`
  - `StatePersistence` extended: save/restore tabs on exit/launch

- **Tab Bar UI (Stage 2)**
  - `TabBarView` — horizontal scrollable tab bar above breadcrumb in each panel
  - `TabItemView` — individual tab with macOS-style truncated name, folder/archive icon, close button
  - Tab bar auto-hides when single tab (clean single-tab experience)
  - Active tab: highlighted background, accent border, orange folder icon, medium font
  - Hover: close button appears, subtle background, separator border
  - Close button hidden on only-remaining tab (cannot close last tab)
  - Auto-scroll to active tab on switch
  - Tooltip shows full path on hover
  - Tab click syncs panel path, scanner, and file list
  - Tab close navigates to adjacent tab automatically
  - Directory navigation (`updatePath`) syncs active tab path
  - Archive entry (`enterArchive`) syncs tab with archive state
  - Integrated into `FilePanelView` above breadcrumb

- **Open in New Tab Action (Stage 3)**
  - `FileAction.openInNewTab` added to file context menu enum
  - `DirectoryAction.openInNewTab` — replaced TODO with full implementation
  - Directory: opens directory in new tab on same panel
  - Archive file: extracts and opens as virtual directory in new tab
  - Regular file: opens containing directory in new tab
  - Symlink directories resolved before opening
  - Shortcut hint `⌘T` shown in both file and directory context menus
  - `FileContextMenu` updated with "Open in New Tab" item
  - `DirectoryActionsHandler.openDirectoryInNewTab()` — validates path, adds tab, navigates
  - `DirectoryActionsHandler.openFileInNewTab()` — archive-aware, handles regular files
  - `FileActionsHandler` dispatches `openInNewTab` to shared implementation

- **Fix: Archive Open behavior — Total Commander style (Stage 3.5)**
  - Context menu "Open" on archive files now opens archive as virtual directory
    (was incorrectly delegating to Finder/Archive Utility via NSWorkspace)
  - `FileActionsHandler.openFileOrArchive()` — archive-aware Open action
  - Context menu "Open" on directories now navigates into directory
    (was a no-op stub "handled by double-click")
  - `DirectoryActionsHandler.openDirectoryInPlace()` — enters directory in current tab
  - Double-click behavior unchanged (already correct in FilePanelView)

- **HotKeys for Tabs (Stage 4)**
  - `HotKeyAction`: `newTab`, `closeTab`, `nextTab`, `prevTab`
  - Default bindings: `⌘T` (new tab), `⌘W` (close tab), `⌘⇧]` (next), `⌘⇧[` (prev)
  - `⌘T` on directory → new tab with that directory
  - `⌘T` on archive → new tab with extracted archive
  - `⌘T` on file → new tab with containing directory
  - `⌘T` with nothing selected → new tab with current path
  - `⌘W` closes active tab (ignored if only one tab)
  - `⌘⇧]` / `⌘⇧[` cycle through tabs with wrap-around
  - All tab switching syncs panel path, scanner, and file list
  - User-configurable via HotKey Settings (same system as all other shortcuts)

- **Tab Context Menu (Stage 5)**
  - Right-click on tab shows context menu (Safari/Finder style)
  - Close Tab (⌘W hint), Close Other Tabs, Close Tabs to the Right
  - Duplicate Tab — creates copy of tab right after original
  - Copy Path — copies tab directory path to clipboard
  - Show in Finder — reveals tab directory in Finder
  - Close disabled when only 1 tab remains
  - `TabManager`: `closeOtherTabs()`, `closeTabsToRight()`, `duplicateTab()`
  - `TabBarView`: extracted `syncToActiveTab()` helper, DRY refactor

### Changed
- Version bumped to 0.9.2

### New Files
- `Features/Tabs/TabItem.swift` — single tab data model
- `Features/Tabs/TabManager.swift` — tab collection manager per panel
- `Features/Tabs/TabBarView.swift` — scrollable tab bar for panel
- `Features/Tabs/TabItemView.swift` — single tab button with close action
- `Features/Tabs/TabContextMenu.swift` — right-click menu for tabs

## [Unreleased]

### Planned
- Context menu enhancements (colored icons) — future enhancement

### Added
- **Multi-Selection (Finder + Total Commander hybrid)**
  - **Cmd+Click** — toggle individual file mark (Finder style)
  - **Shift+Click** — range select from anchor to clicked file (Finder style)
  - **Insert key** — toggle mark and move to next file (Total Commander style)
  - **Num+/Num-** — mark/unmark files by wildcard pattern
  - **Ctrl+A** — mark all files; **Num*** — invert marks
  - All selection modes share the same `markedFiles` set
- **Group Context Menu** — when files are marked, right-click shows batch menu
  - Header with "N items selected" count
  - Available actions: Cut, Copy, Paste, Compress, Share, Show in Finder, Move to Trash
  - Single-file menu shown when no marks present
- **Batch-Aware File Operations**
  - Cut, Copy, Compress, Pack, Share, Reveal in Finder, Delete — all operate on
    marked files when present, fall back to single file otherwise
  - Single-file actions (Open, Rename, Get Info, Duplicate, Quick Look) always
    operate on the clicked file only
- **Multi-File Drag & Drop**
  - Dragging a marked file drags all marked files together
  - `NSItemProvider` with `registerFileRepresentation` for each URL (Finder-compatible)
  - Drag preview shows badge with total count and "and N more" subtitle
- **Selection Status Bar** — bottom bar shows marked count, total size, and disk free space
- **Navigation History** — Back/Forward navigation fully functional
  - Every directory change recorded in `SelectionsHistory`
  - BreadCrumb back arrow, context menu Back/Forward, all wired up
  - `isNavigatingFromHistory` guard prevents history corruption
- **Find Files Close button** — large Close button with Esc shortcut
- **Find Files window follows main app** — `NSPanel` with `.floating` level, `hidesOnDeactivate`
- **Input area border** in Find Files — thin `separatorColor` rounded rectangle around form

### Changed
- **Marked file style** — Total Commander visual style:
  - Dark red text color (`#B30000`), semibold weight, 14pt font (vs 13pt normal)
  - Dark red checkmark icon (11pt) next to file name
  - Status bar indicators in matching dark red
- **Major code refactoring** — split oversized classes into modular components
  - `FindFilesEngine` (826 lines) → 5 files in `FindFiles/Engine/`
  - `ArchiveManager` (480 lines) → 6 files in `Archive/`
  - `PanelsRowView` (332 lines) → coordinator + `PanelDividerView`
  - `FileRow` (347 lines) → FileRow + `DragPreviewView`
  - No file exceeds 410 lines; 66% reduction in largest file
- **Parent entry `...`** — renamed from `..`, bold 14pt font, larger icon, always pinned to top regardless of sort
- **Find Files divider** — compact layout, separator right after input area instead of 50/50 split
- **Swift 6.2 concurrency fixes**
  - `FindFilesArchiveSearcher`: `actor` → `enum` with `static` methods + `ArchiveSearchDelta` return
  - `@concurrent` on all async static methods in `ArchiveExtractor`, `ArchiveRepacker`, `FindFilesArchiveSearcher`
  - `ScannedFileEntry` Sendable struct replaces non-Sendable `URLResourceValues` in async loops
- **README Architecture** — updated to reflect new `Archive/`, `FindFiles/Engine/` directory structure
- **All comments in English** — replaced remaining Russian comments in `ToolTipMod`, `BreadCrumbView`
- **Logging tags updated** — `[FindEngine]` `[ArchiveSearcher]` `[Extractor]` `[Repacker]` `[FormatDetector]`

### Fixed
- **List scroll jump on selection** — removed auto-scroll-to-center behavior; user controls scroll position
- **Back navigation after `...`** — `updatePath()` now records history; BreadCrumb back arrow works
- **Context menu Back/Forward** — implemented (was TODO stub), enabled/disabled based on history state
- **`...` sorting** — parent entry always pinned to top, never participates in sort

### New Files
- `ClickModifiers.swift` — enum for click modifier detection (none/command/shift)
- `MultiSelectionAction.swift` — batch action enum for group operations
- `MultiSelectionContextMenu.swift` — context menu view for multiple selected items
- `MultiSelectionActionsHandler.swift` — coordinator extension for batch action dispatch

### Planned
- Batch rename for marked files
- File preview with Quick Look integration
- Move/Rename operations (F6)

## [0.9.1.1] - 2025-01-28

### Added
- **Finder-Style File Table** — complete visual redesign
  - Clean selection: solid blue fill without borders or rounded corners
  - Standard system fonts (SF Pro) instead of custom styling
  - 16pt icons matching Finder's compact view
  - Zebra stripes using system alternating colors
  - "Alias" terminology for symlinks (matches Finder)
- **New Table Columns**
  - Permissions column: Unix-style (rwxr-xr-x) in monospaced font
  - Owner column: file owner username display
- **Sortable Column Headers**
  - All columns now sortable (Name, Size, Date, Permissions, Owner, Type)
  - Visual sort indicators on all columns (chevrons)
  - Active sort column highlighted with accent color
  - Sticky headers: column headers stay visible during scroll

### Changed
- Column order: Name | Size | Date | Permissions | Owner | Type
- Date format: dd.MM.yyyy HH:mm (European style)
- Size display: "—" for directories, "Alias" for symlinks, "0 KB" for empty files

### Fixed
- Column headers now respond to clicks for sorting (was broken)
- Header dividers no longer intercept click events

### Performance
- Removed verbose logging from sorting and formatting functions
- Split complex SwiftUI views for faster type-checking compilation
- Extracted DropTargetModifier to simplify FileRow body

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

[Unreleased]: https://github.com/senatov/MiMiNavigator/compare/v0.9.2...HEAD
[0.9.2]: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.1...v0.9.2
[0.9.1.1]: https://github.com/senatov/MiMiNavigator/compare/v0.9.1...v0.9.1.1
[0.9.1]: https://github.com/senatov/MiMiNavigator/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/senatov/MiMiNavigator/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/senatov/MiMiNavigator/compare/v0.1.0...v0.8.0
[0.1.0]: https://github.com/senatov/MiMiNavigator/releases/tag/v0.1.0

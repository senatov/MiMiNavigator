# Changelog

All notable changes to MiMiNavigator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.8.1] — 2026-04-24

> **Release notes**
> Find Files and startup polish release.
> Advanced search now has a practical "potential user ballast" workflow with user-chosen age/date criteria,
> better pruning of macOS/runtime-owned locations, and clearer Media Convert-style dialog controls.

### Added
- **Find Files advanced template: Potential user ballast** — searches broad user-writable locations, including `/Library`, while skipping protected OS roots and package/runtime areas that are still owned by installed software
- **Age/date search controls** — user can search by an explicit "since" date or by age in days, months, or years
- **Modified/accessed criteria modes** — choose "not modified", "not accessed", or both, instead of filling separate mandatory fields
- **Deletable-only filtering** — ballast search can skip matches the current user cannot remove

### Changed
- **Find Files dialog redesign** — advanced section and bottom buttons now follow the calmer Settings / Media Convert visual style
- **Search pruning** — Python framework tests, `__pycache__`, package internals, caches, VCS folders, and macOS-controlled locations are filtered out more aggressively when they are part of installed software
- **Search labels** — ambiguous wording such as "Return files only" was replaced with clearer file/folder scope wording

### Fixed
- **Find Files size column** — fixed invalid system-size placeholders in search results
- **Startup remote restore** — saved SFTP/SMB connections no longer trigger noisy credential or invalid-path prompts during app startup
- **Keychain prompts** — reduced repeated macOS Keychain permission prompts for saved remote connections on the same user account

---

## [0.9.7.4.1] — 2026-04-15

> **Release notes**
> Hotfix: unified dialog buttons (glass style), Finder-compatible clipboard.
> Copy/Paste from MiMi to Finder and other apps now works correctly for all file types including `.app` bundles.

### Fixed
- **Clipboard copy/paste to Finder** — pasteboard was writing only `.string` type; Finder and other apps couldn't paste files copied in MiMi. Now writes `public.file-url` via `writeObjects` + text fallback
- **`.app` bundle paste** — application bundles now correctly paste to Finder, other file managers, and between MiMi panels

### Changed
- **Dialog buttons → `DownToolbarButtonView`** — unified glass-style buttons in TransferConfirmDialog, FullDiskAccessOnboarding, AboutView, ToolbarCustomizeView (10 buttons replaced)

---

## [0.9.8] — 2026-04-24

> **Release notes**
> Toolbar Customize polish release.
> The dialog now uses a clearer card-based layout, drag-to-remove works as advertised,
> first right-click reliably brings the panel to the front, and `Done` closes it in one click.

### Changed
- **Toolbar Customize dialog redesign** — clearer section hierarchy, calmer spacing, stronger visual separation between current toolbar and available items
- **Toolbar item chips / palette cells** — updated icon cards, visibility badges, and insertion markers for easier scanning during drag-and-drop
- **Toolbar release packaging docs** — README and changelog now reflect the new release and notarized DMG flow

### Fixed
- **First toolbar right-click opening** — customize panel open is deferred to the next main turn and re-asserts z-order after menu tracking ends, so it appears above other windows immediately
- **`Done` button close race** — closing state is now set before the panel loses focus, preventing the dialog from reappearing and requiring a second click
- **Drag-to-remove behavior** — dropping an active toolbar item back into Available Items now really hides it instead of only resetting drag state
- **Toolbar visibility accounting** — fixed item `menuBarToggle` no longer pollutes customizable visibility counts or minimum-visible-button enforcement

---

## [0.9.7.4] — 2026-04-15

> **Release notes**
> First notarized release with a fancy DMG installer (drag-to-Applications).
> Major feature: Convert Media panel, External Tools registry, context menu overhaul,
> autofit rework, archive timestamp fixes, VLC preview migration.
> 30 commits since v0.9.7.3.

### Added
- **Convert Media feature** — dialog + service with ffmpeg/ImageIO/Lottie support for 20+ formats, wired to context menu
- **Convert Media panel** — non-modal NSPanel (like Network Neighborhood), glass sections, coordinator-based structure
- **VLC video preview** — started migrating Media Info preview from AVPlayer to VLC (`VLCVideoView` / `VLCMediaPlayer`), fallback to file icon
- **External Tools registry** — `ExternalToolRegistry`, `(i)` install popover, Settings pane, `SystemSettingsHelper` deeplinks; killed hardcoded 7z paths
- **System permissions checker** — automatic Full Disk Access / Automation permission detection and onboarding
- **"File Ops" submenu** — cut/copy/paste/duplicate grouped into submenu; added to multi-selection, directory, and background panel menus
- **Background panel menu** — paste, new folder, new file, copy path, add to favorites
- **Fancy DMG installer** — notarized DMG with background image, arrow, and `/Applications` symlink (drag-to-install UX)

### Changed
- **Context menu overhaul** — refactored coordinator extensions, clean menu integration, `⌥ R-Menu` shows File Operations vs. File Type operations
- **Autofit rework** — `AutoFitScheduler` singleton eliminates per-view race conditions; sequential L→R with gap; surplus width → Name column
- **PackDialog** — non-modal NSPanel, autofit surplus→Name, trimmed weighted avg `Σ(w_i²) / Σ(w_i)`
- **DMG/PKG/ISO/JAR** — double-click opens with system, not as archive; extract via R-Menu only
- **`.app` bundle copy** — treat packages as opaque files, no recursion into bundle contents
- **WindowFrameRestorer** — poll-based approach instead of notification-based
- **HIGAutoFocus** — retry 3× with fallback to rightmost button
- **Glass style** — bottom toolbar buttons with glass hover styling
- **Media Info panel** — refactored into smaller logical sections/extensions
- **License updates** — added omaralbeik/VLC and other third-party licenses

### Fixed
- **APFS firmlink double-click** — `URL.resourceValues` lies on `/tmp`, `/var`, `/etc`; now uses `FileManager.fileExists(atPath:isDirectory:)`
- **Archive timestamps** — better ZIP and TAR timestamp preservation during extraction
- **Drag-and-drop** — refactored `DragNSView` helpers, ignore same-panel return drops
- **Reconnect-on-start** — disabled auto-reconnect after manual remote disconnect
- **Startup state restore** — improved restore flow, cleanup noisy logs, block refresh during termination
- **Compilation errors** — fixed function access levels, exhaustive switch for `.convertMedia`

---

## [0.9.7] — 2026-03-17

> **Release notes**  
> This build is all about internals — no shiny new UI, just deep engine work: actor isolation fixes, popup infra refactor, non-blocking path resolution, SFTP error diagnostics, proper `ErrorAlertService`.  
> Running the app daily for a week now, straight from Xcode — catching & fixing live bugs.  
> Expect ~1 more month of active bugfixing, then a public release.

### Fixed
- **`DualDirectoryScanner` brace corruption** — duplicate `func setRightDirectory` declaration + stray closing brace pushed all `private`/`static` methods out of actor scope; 35 compiler errors eliminated
- **`DirectorySizeService` actor boundary** — repeated edit-induced brace drift kept closing actor too early, sending `static func computeShallowSize` / `computeFullRecursive` outside type
- **`NSWorkspace.didMountVolumeNotification` @MainActor** — replaced with raw `Notification.Name("NSWorkspaceDidMountNotification")` and correct `NSWorkspace.shared.notificationCenter` subscription
- **`PathAutoCompleteField` `guard let` on non-Optional NSPanel** — removed spurious guard

### Changed
- **`PopupEventMonitors`** extracted to `GUI/Sources/Features/Popups/` — `@MainActor` class owns NSEvent local monitors; `nonisolated(unsafe)` confined to three `Any?` fields used only in `deinit`; `install()` accepts `onClickOutside` + `shouldDismissOnClick` guard closure + `installResignObserver` flag
- **`FileInfoPopupController`** and **`ConnectErrorPopupController`** moved to `Features/Popups/`; replaced 3×`nonisolated(unsafe)` + `installMonitors`/`removeMonitors`/`deinit` with single `monitors.install(panel:onHide:)`
- **`PathAutoCompleteField.AutoCompletePopupController`** — dropped `@unchecked Sendable`, same monitor migration; `installMonitors(for:)` uses `shouldDismissOnClick` for anchor-rect guard and disables resign observer
- **`ErrorAlertService`** added (`GUI/Sources/Services/`) — `@MainActor enum` with `show` / `confirm` / `promptPassword`; replaces 4× scattered `NSAlert().runModal()` in `DuoFilePanelActions`, `AppState+Navigation`, `AppState+Archive`, `AppState+SearchResults`
- **`updatePath(_:for:)` non-blocking** — `FileManager.fileExists` moved off MainActor into `Task.detached`; `applyPathUpdate` handles pure-UI mutation; eliminates potential NAS/SMB freeze on main thread
- **`RemoteConnectionManager.updateServerResult`** unified — accepts `errorDetail: String?`; success and fail paths both route through it; saves `lastErrorDetail` to `RemoteServer`
- **`ConnectToServerView`** — `connectionError` and `ConnectErrorPopupController` now reset/hidden when user switches server in sidebar
- **`NoOpRemoteFileProvider`** replaces `FTPFileProvider()` stub for SMB/AFP protocols; throws `notImplemented` loudly instead of silently misbehaving
- **`DirectorySizeService.permanentlyUnavailable`** — `registerVolumeMountObserver()` clears `/Volumes/` entries via `NSWorkspace.shared.notificationCenter` on disk mount

### Added
- **`ConnectErrorPopupController`** — yellow HUD popup (same style as `FileInfoPopupController`) shows full SFTP/FTP connection diagnostics; triggered by `⚠` button replacing static red error text
- **`RemoteServer.lastErrorDetail`** — new field stores full `error.localizedDescription` from failed connect attempt

---

## [0.9.6] — 2026-03-10
### Added
- **Breadcrumb hover-expand (Finder-style)** — truncated segments spring-expand on hover
- **Custom thumbnail slider** — macOS Sound-panel style, theme-tinted, 3D knob
- **Scroll jump buttons (3D)** — square embossed buttons at scrollbar edges

### Changed
- **Slider performance** — local State during drag, commit on mouse-up only
- **safeAreaInset** — 40pt to 4pt, scrollbar reaches bottom
- **Slider clarity** — track opacity 0.55, knob 16pt, inner shadow

---

## [Unreleased] — 2026-03-06

### Added
- **Thumbnail View** — new grid-based view mode per panel
  - Toggle list ↔ thumbnail via segmented control (moved to main toolbar, right side)
  - `QLThumbnailGenerator` for images, video frames, PDF pages; SF Symbol fallback for all other types
  - Cell size range **16–900 pt** adjustable via inline slider in status bar
  - Slider appears/disappears with animation only when panel is in thumbnail mode
  - Thumbnail size persisted per panel (left/right) via `UserDefaults`
  - Context menu (R-Menu) fully supported: `FileContextMenu` / `DirectoryContextMenu` per cell
  - Drag-and-drop from thumbnail cells: respects marked files (same logic as list mode)
  - Drag preview: thumbnail image or SF Symbol + item count badge for multi-file drags
  - File name: single-line, `truncationMode(.middle)` — macOS-standard no wrapping
- **View-mode toolbar buttons** — list/grid `Picker` added to `AppToolbarContent` as separate `ToolbarItem(.primaryAction)` in own framed `ToolbarButtonGroup`; switches focused panel's view mode
- **Thumbnail size slider in status bar** — replaces bottom-toolbar slider; sits left of item count, width 90 pt

### Changed
- **`OpenWithSubmenu`** — apps pre-loaded via `_apps = State(initialValue:)` in `init` (was computed inside `body` → caused menu flicker on every hover)
- **`OpenWithService` LRU** — recently-used apps stored per file extension (`openWithLRU` dict in `UserDefaults`), max 5 entries, newest-first; `recordLRU(bundleID:ext:appURL:)` persists app URL for "Other..." picks (`openWithAppURLs` key); `getApplications` restores LRU apps missing from Launch Services list (e.g. GIMP picked via "Other..."); `showOpenWithPicker` calls `recordLRU` after user selection
- **`ToolbarButtonGroup`** — padding `10/4`, spacing `6`, `strokeBorder` `0.5pt`; all `ToolbarItem`s on `.primaryAction` (right side of toolbar)
- **`ViewModeToolbarItem`** — receives `appState` as explicit parameter (not `@Environment`) to avoid macOS toolbar crash: `No Observable object of type AppState found`
- **Thumbnail cell size clamp** — `setThumbSize` now clamps to `16…900` (was `80…300`)

### Fixed
- **`OpenWithSubmenu` flicker** — `.task` did not fire inside `.contextMenu` on macOS; replaced with `State(initialValue:)` pre-load in `init`
- **`AppToolbarContent` crash** — `@Environment(AppState.self)` inside `ToolbarContent` is unreliable on macOS (toolbar renders outside SwiftUI view tree); fixed by passing `appState` as explicit init parameter
- **Unused variable warnings** — `let ms = ...` in `FileTableView+State` replaced with `_ = ...`
- **Spurious `try?` warnings** — removed from `TabManager` and `StatePersistence` (`resolvingSymlinksInPath()` is non-throwing)



### Added
- **Live color theming** — all file row colors (file name, directory name, symlink, selection active/inactive) now read from `ColorThemeStore` and update instantly when changed in Settings → Colors, no restart required
- **Symlink icon visual identity** — symlink folders now rendered with deep blue tint overlay + large yellow arrow badge in bottom-left corner, clearly distinguishable from regular directories at a glance
- **Color presets in Settings** — Default, Warm, Midnight, Solarized themes selectable from dropdown; live preview swatches shown inline
- **Per-token color overrides** — each color token (panel background, file name, dir name, symlink, selection, accent, dialog background) independently overridable via color well in Settings → Colors

### Changed
- **Selection highlight style** — replaced full-width flat rectangle with rounded pill (`cornerRadius 6`, horizontal padding 4pt, vertical 1pt); color sourced live from `ColorThemeStore.selectionActive / selectionInactive`
- **Panel divider** — passive state: 2pt solid grey `alpha 0.55` with white highlight (left edge) and dark shadow (right edge) for 3D raised effect; active/drag state: 5pt orange
- **Panel borders** — 1.5pt soft grey with subtle drop shadow; focused panel slightly brighter than unfocused
- **File selection behavior** — ESC clears marks only, never clears file selection; switching panels auto-selects first file if panel had no prior selection
- **`#colorLiteral` enforced** — all hardcoded color literals in `AliasIconComposer`, `FileRow`, `FileRowView`, `FilePanelStyle` converted to `#colorLiteral` form per project coding standards
- **`FilePanelStyle`** — `orangeSelRowFill` / `yellowSelRowFill` are now compile-time fallbacks only; live values come from `ColorThemeStore` via `FileRow`

### Fixed
- **Alias/symlink badge** — removed orange SwiftUI overlay (was rendering over icon regardless of compositing); badge now composited directly by `AliasIconComposer` using `NSWorkspace` + manual tint/arrow pass
- **`FilePanelStyle` `@MainActor` error** — removed computed vars that referenced `ColorThemeStore.shared` from nonisolated enum context; restored `static let` constants
- **`ColorThemeStore` live update** — `FileRow` and `FileRowView` now hold `@State private var colorStore = ColorThemeStore.shared`; SwiftUI re-renders rows on theme change via `@Observable`

---

## [Unreleased] — 2026-02-24

### Added
- **Citadel SFTP library** — added SPM dependency (orlandos-nl/Citadel 0.7.x) for native SFTP connectivity via NIOSSH. `SFTPFileProvider` uses `SSHClientSettings`, `SSHClient.connect(to:)`, `SFTPClient.listDirectory()` with proper `SFTPPathComponent` parsing (filename, permissions, size, modification date).
- **Disconnect button** — replaced Browse with Disconnect in Connect to Server dialog. Disconnects active session and restores file panel to previous local path.
- **Session context menu** — right-click on session history row: Connect / Disconnect / Delete. Delete terminates connection, removes from keychain and store.
- **Connection reuse** — Connect button reuses existing connection if server already connected (no duplicate sessions). Sets it as active and shows remote directory.
- **Local path restoration** — `AppState.savedLocalLeftPath`/`savedLocalRightPath` remember panel path before switching to remote; restored automatically on disconnect.

### Fixed
- **Network Neighborhood menu** — was setting unused `appState.showNetworkNeighborhood` flag; now calls `NetworkNeighborhoodCoordinator.shared.toggle()` same as toolbar button.
- **Show/Hide Hidden Files menu** — was missing `forceRefreshBothPanels()` after toggle; panels now refresh immediately.
- **Refresh Panels menu** — now refreshes both panels (was only focused panel); renamed to "Refresh Panels".
- **SMB mount Unicode failures** — `mount_smbfs` failed on share names with curly quotes (‘kira’s’), combining diacriticals (öffentlicher), spaces. New `sanitizeMountName()` normalizes Unicode (NFC), strips unsafe characters, keeps only alphanumerics/hyphens/dots.
- **Dialog centering** — Connect to Server, Network Neighborhood, Find Files dialogs now open centered over main window.

### Removed
- **Brief View menu item** — removed unimplemented stub (Norton Commander legacy, not applicable).

### Changed
- **Multi-vendor router web UI support** — MiMiNavigator can now open admin panels for TP-Link, Netgear, D-Link, Asus, Linksys, Mikrotik, and Huawei routers, not just Fritz!Box. `NetworkHost.routerDomain` maps router names to vendor-specific domains (`tplinkwifi.net`, `routerlogin.net`, `router.asus.com`, etc.). Extended `routerKeywords` with model-specific names (Archer, Nighthawk, RT-AX). HTTP exceptions in `Info.plist` now fully utilized by network discovery code.
- **MAC vendor lookup improvements** — `MACVendorService` now uses actor-based caching for instant repeated lookups, respects API rate limits (1 req/sec), and shows error messages ("Network error", "Rate limit exceeded") instead of silently failing. Timeout reduced from 5s to 3s for better responsiveness.

### Changed
- **Packages/ extracted to private git submodule** — `NetworkKit`, `FavoritesKit`, `LogKit` moved to private repo `github.com/senatov/MiMiKits`, connected back as git submodule at `Packages/`. Xcode project unchanged, full debug/edit/commit workflow preserved.
- **Package.resolved now tracked** — Following Apple's recommendation for app projects, `Package.resolved` is now committed to ensure reproducible builds across all developers. Added exception in `.gitignore` for `xcshareddata/swiftpm/Package.resolved`.
- **Submodule packages: added .gitignore** — Created `.gitignore` files for `LogKit` and `NetworkKit` packages to prevent tracking user-specific Xcode files (`xcuserdata/`, scheme management).

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

[Unreleased]: https://github.com/senatov/MiMiNavigator/compare/v0.9.8...HEAD
[0.9.8]: https://github.com/senatov/MiMiNavigator/compare/v0.9.7.4.1...v0.9.8
[0.9.7.4]: https://github.com/senatov/MiMiNavigator/compare/v0.9.7.3...v0.9.7.4
[0.9.7]: https://github.com/senatov/MiMiNavigator/compare/v0.9.6...v0.9.7
[0.9.6]: https://github.com/senatov/MiMiNavigator/compare/v0.9.4...v0.9.6
[0.9.4]: https://github.com/senatov/MiMiNavigator/compare/v0.9.3.2...v0.9.4
[0.9.3.2]: https://github.com/senatov/MiMiNavigator/compare/v0.9.3...v0.9.3.2
[0.9.2]: https://github.com/senatov/MiMiNavigator/compare/v0.9.1.1...v0.9.2
[0.9.1.1]: https://github.com/senatov/MiMiNavigator/compare/v0.9.1...v0.9.1.1
[0.9.1]: https://github.com/senatov/MiMiNavigator/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/senatov/MiMiNavigator/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/senatov/MiMiNavigator/compare/v0.1.0...v0.8.0
[0.1.0]: https://github.com/senatov/MiMiNavigator/releases/tag/v0.1.0

# MiMiNavigator — Codex AI Guidelines

## Project Overview
MiMiNavigator is a dual-panel file manager for macOS, built with Swift 6.2 and SwiftUI. Inspired by Total Commander and Norton Commander.

## ⚠️ CRITICAL RULES — NEVER VIOLATE
1. **Commit completed repository changes unless the user explicitly says not to; never push without an explicit request**
2. **NEVER add AI signatures in code** — No AI attribution comments or markers
3. **Always run `Scripts/git_cleanup.zsh`** before any git commit
4. **Use zsh only** — Never bash or default shell for MiMiNavigator work
5. **Commit Packages/** submodule changes separately (cd into Packages dir first)
6. **Git commit messages**: short English, lowercase, no slangy

## 🎯 Development Guidelines

### Code Quality
- **No file over 400 lines** — extract to new files
- **English comments only** — no Russian/German in code
- **`#colorLiteral` for colors** — never hardcoded RGB strings
- **Logging tags**: `[Component]` format (e.g. `[Rename]`, `[Scan]`, `[FileOps]`, `[Selection]`)
- **`// MARK: - Name`** directly above every class/struct/enum/non-trivial method
- **No blank lines inside method bodies**
- **`nonisolated(unsafe)`** for Swift 6 NSCache statics; for popup event monitors use `PopupEventMonitors` class (three `Any?` fields only)

### Swift and SwiftUI Review
- Before changing SwiftUI code, trace the affected state owner, data dependencies, view identity, and event path. Review the surrounding declarations, not only the edited lines.
- For new or substantially changed view sections with their own data dependencies, prefer a dedicated `View` type receiving only the values it needs over a computed `some View` property or helper method. Do not rewrite unrelated existing helpers merely to satisfy this preference.
- In `List` and lazy stacks, keep `ForEach` identity stable and produce a predictable number of rows per element. When membership is conditional, prepare the filtered collection before `ForEach`; avoid repeatedly filtering a large collection in `body`.
- If SwiftFairy is connected and available, consult its relevant guidance for meaningful Swift/SwiftUI changes and audit the affected code afterward. Check each finding against the surrounding code before applying it. Do not block work or install/activate SwiftFairy just to satisfy this review step.
- For changed UI interactions, verify the running Debug app, including visible hit areas and accessibility actions where relevant. A static review and a successful build do not establish interaction correctness.

### Programmatic Scrolling
- Identify whether the target is a SwiftUI `ScrollView`, `List`, or an AppKit `NSScrollView` before choosing an API. Use `ScrollViewReader` for `List`; consider `ScrollPosition` for new `ScrollView` interactions that need a bound item, edge, or offset. Do not replace an existing reader without preserving its scrolling behavior.
- Use `defaultScrollAnchor` for initial placement, not for later jumps. For ID-based `ScrollPosition` scrolling, give targets stable explicit IDs and configure the intended anchor. To read the visible ID during user scrolling, establish the ID type and use `viewID`; `edge`, `point`, `x`, and `y` do not track manual movement.
- Use `onScrollGeometryChange` when continuous user-driven offset or geometry is actually needed. Project only the small `Equatable` value the feature uses, so scrolling does not trigger unnecessary view updates.
- Preserve the file panel's Finder-style minimum scrolling, pinned header, and native scroll-view setup when changing its navigation. Verify trackpad scrolling, keyboard selection and jumps, resize, and jump buttons in the running app.

### Build & Run
- **Builds only on user's Mac** using zsh, never on remote
- `⌘R` in Xcode or `Scripts/build_debug.zsh`
- **Before a manual Xcode build**: run `zsh Scripts/stamp_version.zsh` to sync version from git tag; `Scripts/build_debug.zsh` already performs this step

### Version Management
- `Scripts/refreshVersionFile.zsh` — main script: writes `curr_version.asc` + updates `MARKETING_VERSION` in pbxproj from git tag
- `Scripts/stamp_version.zsh` — thin wrapper calling `refreshVersionFile.zsh`
- Version in window title reads from `CFBundleShortVersionString` (plist)
- DEV BUILD badge reads from `curr_version.asc` (date + host)

### Architecture Patterns
| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState`, `MultiSelectionManager`, `TabManager` |
| `@MainActor` + `@Observable` | `CntMenuCoord` — singleton, all context menu actions |
| `actor` | `DualDirectoryScanner`, `ArchiveManager`, `FindFilesEngine` |
| `AsyncStream` | `FindFilesEngine` streaming results |
| `AutoFitScheduler` | Singleton for sequential column autofit (L→R), no per-view race |
| `ExternalToolRegistry` | Registry of CLI tools (7z, ffmpeg) with install status + Settings pane |
| `CloudLinkShortener` | Shared Google Drive/Dropbox shortener using `mimiNavi` + 8 random Base62 characters |
| Swift Package (dynamic) | `FavoritesKit`, `LogKit`, `NetworkKit` |

### Private MiMiKits workflow
- Put reusable domain and service fixes in the owning package under `Packages/`; do not duplicate them in the application as a binary-package workaround.
- After changing private package sources, run `zsh Scripts/rebuild_private_kits.zsh`. It rebuilds the XCFramework artifacts and compiles a source-free verification copy of MiMiNavigator against those exact binaries.
- Treat a normal app build against the checked-in remote wrappers as insufficient evidence for uncommitted MiMiKits changes.
- Keep `Packages/` and the main repository changes separate for review and commit them separately under the Git rule above.

### Firmlink Handling
macOS firmlinks (`/tmp` ↔ `/private/tmp`, `/var` ↔ `/private/var`, `/etc` ↔ `/private/etc`) cause:
- `URL.resourceValues(forKeys: [.isDirectoryKey])` returning `isDirectory == false` for `/tmp`
- `CustomFile.urlValue` storing `/private/tmp/X` while file is at `/tmp/X`
- Always use `FileManager.fileExists(atPath:isDirectory:)` as fallback for directory checks
- Use `resolveSourceURL()` pattern for file operations on firmlink paths

### Xcode Project
- Xcode 16+ filesystem-based structure — files in folders appear in build automatically
- Never edit `project.pbxproj` to add/remove source files
- Do edit it automatically when adding/removing packages or targets

### DMG Release
- `Scripts/notarize_release.zsh <version>` — full pipeline: build → sign → DMG → notarize → staple → GitHub
- DMG has background image + `/Applications` symlink (drag-to-install UX)
- `Scripts/generate_dmg_background.zsh` — generates Retina background (requires Pillow)

### Context Menu Architecture
- `⌥ R-Menu` (Option+right-click) shows alternative operations (File Ops vs. File Type)
- "File Ops" submenu groups cut/copy/paste/duplicate
- Background panel menu: paste, new folder, new file, copy path, add to favorites
- DMG/PKG/ISO/JAR: double-click opens with system; extract only via R-Menu

### Cloud Share+Link
- Google Drive and Dropbox use the shared `CloudLinkShortener`
- Short aliases must remain `mimiNavi` + 8 random Base62 characters (spoo.me maximum: 16 total)
- Do not use sequential, timestamp-based, filename-based, or short UUID-prefix aliases
- Keep aliases URL-safe; punctuation such as `!` must not be introduced
- Dropbox OAuth uses PKCE and Keychain refresh-token storage
- Full design notes: `GUI/Docs/Cloud_Share_Link.md`

### Git Workflow
- Never git push automatically — only commit
- Iakov pushes manually himself
- Commit message style: short English, e.g. `"fix rename: firmlink resolve, panel tracking"`
- After every completed fix, include a detailed proposed commit message of 250-450 characters explaining the problem and what was changed.

## 📁 Key Directories

```
GUI/Sources/
├── App/                # Entry point, AppBuildInfo, AppToolbarContent
├── States/AppState/    # Global state, selection, navigation, refresh
├── Features/
│   ├── Panels/         # File panels, table, rows, ZebraBackgroundFill
│   ├── Tabs/           # Tab system
│   ├── Network/        # SMB/AFP discovery
│   ├── ConvertMedia/   # Convert Media dialog, service, ffmpeg/ImageIO/Lottie
│   └── ConnectToServer/# SFTP/FTP connectivity
├── ContextMenu/
│   ├── ActionsEnums/   # FileAction, DirectoryAction, etc.
│   ├── Dialogs/        # RenameDialog, HIGAlertDialog, PackDialog, etc.
│   ├── Menus/          # Context menus
│   └── Services/
│       ├── Coordinator/    # FileActionsHandler, DirectoryActionsHandler, ActiveDialog
│       ├── FileOperations/ # FileOperationsService + extensions (Delete, Rename, SymLink)
│       ├── DropboxShare/   # Dropbox OAuth PKCE, mounted paths, API sharing
│       └── GoogleDriveShare/# Google OAuth, upload API, shared CloudLinkShortener
├── Services/
│   ├── Archive/        # VFS, extract, repack
│   └── Scanner/        # DualDirectoryScanner, FSEventsDirectoryWatcher
├── FindFiles/          # Search UI and engine
├── ExternalTools/      # ExternalToolRegistry, install popover, Settings pane
├── MediaInfo/          # Media info panel (VLC preview migration)
├── BreadCrumbNav/      # PathAutoCompleteField (NSPanel popup, click-outside dismiss)
├── HotKeys/            # Keyboard shortcuts
└── Settings/           # Preferences UI

Packages/               # git submodule → github.com/senatov/MiMiKits
├── ArchiveKit/
├── FavoritesKit/
├── FileModelKit/       # CustomFile model
├── LogKit/
├── NetworkKit/
└── ScannerKit/
```

## 🔧 Common Tasks

### Add new file to project
1. Create the file in the appropriate directory; Xcode's filesystem-based structure includes it automatically.
2. Edit `project.pbxproj` only when adding or removing a package or target.

### Run before commit
```zsh
cd /Users/senat/Develop/MiMiNavigator
zsh Scripts/git_cleanup.zsh
```

### Update version before build
```zsh
zsh Scripts/stamp_version.zsh
```

### Log locations
- Console: SwiftyBeaver to stdout
- Sandboxed: `~/Library/Containers/Senatov.MiMiNavigator/Data/Library/Application Support/MiMiNavigator/Logs/MiMiNavigator.log`
- External: `/private/tmp/MiMiNavigator.log`

## ⚠️ Common Mistakes to Avoid

- **Over-Engineering**: Adding "defensive" code not requested. Three similar lines > premature abstraction
- **Guessing Before Reading**: Always read the file before suggesting changes
- **Wrong shell**: Must use zsh, not bash
- **Forgetting Packages/**: Submodule changes need separate commit
- **Firmlinks**: Never trust `URL.resourceValues` for `/tmp`, `/var`, `/etc` — use FileManager fallback
- **Scanner race conditions**: Always call `scanner.clearCooldown(for:)` before explicit `refreshFiles` after file operations
- **Panel detection**: When both panels show same directory, `panelForPath` is ambiguous — pass `panel: PanelSide` explicitly

## Dependencies

- **SwiftyBeaver** — logging
- **Citadel** — SSH/SFTP (orlandos-nl/Citadel)
- **p7zip** — archive formats (`brew install p7zip`)

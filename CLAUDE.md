# MiMiNavigator — Claude AI Guidelines

## Project Overview
MiMiNavigator is a dual-panel file manager for macOS, built with Swift 6.2 and SwiftUI. Inspired by Total Commander and Norton Commander.

## ⚠️ CRITICAL RULES — NEVER VIOLATE
1. **NEVER commit/push without explicit user request** — Wait for user to explicitly ask
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
- **`nonisolated(unsafe)`** for Swift 6 NSCache statics and event monitors in `deinit`

### Build & Run
- **Builds only on user's Mac** via osascript (Control your Mac), never on remote
- Reading, writing, analysis on remote is OK
- `⌘R` in Xcode or `Scripts/build_debug.zsh`
- **Before build**: run `zsh Scripts/stamp_version.zsh` to sync version from git tag

### Version Management
- `Scripts/refreshVersionFile.zsh` — main script: writes `curr_version.asc` + updates `MARKETING_VERSION` in pbxproj from git tag
- `Scripts/stamp_version.zsh` — thin wrapper calling `refreshVersionFile.zsh`
- Version in window title reads from `CFBundleShortVersionString` (plist)
- DEV BUILD badge reads from `curr_version.asc` (date + host)

### Architecture Patterns
| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState`, `MultiSelectionManager`, `TabManager` |
| `@MainActor` + `@Observable` | `ContextMenuCoordinator` — singleton, all context menu actions |
| `actor` | `DualDirectoryScanner`, `ArchiveManager`, `FindFilesEngine` |
| `AsyncStream` | `FindFilesEngine` streaming results |
| Swift Package (dynamic) | `FavoritesKit`, `LogKit`, `NetworkKit` |

### Firmlink Handling
macOS firmlinks (`/tmp` ↔ `/private/tmp`, `/var` ↔ `/private/var`, `/etc` ↔ `/private/etc`) cause:
- `URL.resourceValues(forKeys: [.isDirectoryKey])` returning `isDirectory == false` for `/tmp`
- `CustomFile.urlValue` storing `/private/tmp/X` while file is at `/tmp/X`
- Always use `FileManager.fileExists(atPath:isDirectory:)` as fallback for directory checks
- Use `resolveSourceURL()` pattern for file operations on firmlink paths

### Xcode Project
- Edit `MiMiNavigator.xcodeproj/project.pbxproj` automatically when adding/removing files
- Never ask user to do manual Xcode changes

### Git Workflow
- Never git push automatically — only commit
- Iakov pushes manually himself
- Commit message style: short English, e.g. `"fix rename: firmlink resolve, panel tracking"`

## 📁 Key Directories

```
GUI/Sources/
├── App/                # Entry point, AppBuildInfo, AppToolbarContent
├── States/AppState/    # Global state, selection, navigation, refresh
├── Features/
│   ├── Panels/         # File panels, table, rows, ZebraBackgroundFill
│   ├── Tabs/           # Tab system
│   ├── Network/        # SMB/AFP discovery
│   └── ConnectToServer/# SFTP/FTP connectivity
├── ContextMenu/
│   ├── ActionsEnums/   # FileAction, DirectoryAction, etc.
│   ├── Dialogs/        # RenameDialog, HIGAlertDialog, PackDialog, etc.
│   ├── Menus/          # Context menus
│   └── Services/
│       ├── Coordinator/    # FileActionsHandler, DirectoryActionsHandler, ActiveDialog
│       └── FileOperations/ # FileOperationsService + extensions (Delete, Rename, SymLink)
├── Services/
│   ├── Archive/        # VFS, extract, repack
│   └── Scanner/        # DualDirectoryScanner, FSEventsDirectoryWatcher
├── FindFiles/          # Search UI and engine
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
1. Create file in appropriate directory
2. Edit `project.pbxproj` to add file reference and build phase

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

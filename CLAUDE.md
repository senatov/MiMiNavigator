# MiMiNavigator — Claude AI Guidelines

## Project Overview
MiMiNavigator is a dual-panel file manager for macOS, built with Swift 6.2 and SwiftUI. Inspired by Total Commander and Norton Commander.

## ⚠️ CRITICAL RULES — NEVER VIOLATE
1. **NEVER commit/push without explicit user request** — Wait for user to explicitly ask
2. **NEVER add AI signatures in code** — No AI attribution comments or markers
3. **Always run `Scripts/git_cleanup.zsh`** before any git commit
4. **Use zsh only** — Never bash or default shell for MiMiNavigator work
5. **Commit Packages/** submodule changes separately (cd into Packages dir first)
6. **Git commit messages**: very short, slangy, some typos, mix in German words occasionally

## 🎯 Development Guidelines

### Code Quality
- **No file over 400 lines** — extract to new files
- **English comments only** — no Russian/German in code
- **`#colorLiteral` for colors** — never hardcoded RGB strings
- **Logging tags**: `[COMPONENT]` format (e.g. `[FindEngine]`, `[ArchiveManager]`)

### Build & Run
- **Builds only on user's Mac** via osascript (Control your Mac), never on remote
- Reading, writing, analysis on remote is OK
- `⌘R` in Xcode or `Scripts/build_debug.zsh`

### Architecture Patterns
| Pattern | Usage |
|---------|-------|
| `@Observable` + `@MainActor` | `AppState`, `MultiSelectionManager`, `TabManager` |
| `actor` | `DualDirectoryScanner`, `ArchiveManager`, `FindFilesEngine` |
| `AsyncStream` | `FindFilesEngine` streaming results |
| Swift Package (dynamic) | `FavoritesKit`, `LogKit`, `NetworkKit` |

### Xcode Project
- Edit `MiMiNavigator.xcodeproj/project.pbxproj` automatically when adding/removing files
- Never ask user to do manual Xcode changes

### Git Workflow
- Never git push automatically — only commit
- Iakov pushes manually himself
- Commit message style: `"fix symlink shit"`, `"tabs kaputt, wieder gefixt"`, `"archiv repack done"`

## 📁 Key Directories

```
Gui/Sources/
├── App/                # Entry point, logging
├── States/AppState/    # Global state, selection, persistence  
├── Features/
│   ├── Panels/         # File panels, table, rows
│   ├── Tabs/           # Tab system
│   ├── Network/        # SMB/AFP discovery
│   └── ConnectToServer/# SFTP/FTP connectivity
├── ContextMenu/        # Actions, dialogs, services
├── Services/
│   ├── Archive/        # VFS, extract, repack
│   └── Scanner/        # Directory scanning
├── FindFiles/          # Search UI and engine
├── HotKeys/            # Keyboard shortcuts
└── Settings/           # Preferences UI

Packages/               # git submodule → github.com/senatov/MiMiKits
├── ArchiveKit/
├── FavoritesKit/
├── FileModelKit/
├── LogKit/
├── NetworkKit/
└── ScannerKit/
```

## 🔧 Common Tasks

### Add new file to project
1. Create file in appropriate directory
2. Edit `project.pbxproj` to add file reference and build phase

### Run before commit
```bash
cd /Users/senat/Develop/MiMiNavigator
zsh Scripts/git_cleanup.zsh
```

### Log locations
- Console: SwiftyBeaver to stdout
- File: `~/Library/Logs/MiMiNavigator.log`

## ⚠️ Common Mistakes to Avoid

- **Over-Engineering**: Adding "defensive" code not requested. Three similar lines > premature abstraction
- **Guessing Before Reading**: Always read the file before suggesting changes
- **Wrong shell**: Must use zsh, not bash
- **Forgetting Packages/**: Submodule changes need separate commit

## Dependencies

- **SwiftyBeaver** — logging
- **Citadel** — SSH/SFTP (orlandos-nl/Citadel)
- **p7zip** — archive formats (`brew install p7zip`)

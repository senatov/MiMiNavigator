# Archive Virtual Filesystem & Parent Directory Navigation

## Date: 11-12.02.2026
## Status: Applied

---

## Overview

Two features implemented for MiMiNavigator:

1. **Archive Virtual Filesystem** — archives (.zip, .7z, .tar, etc.) open as virtual directories
2. **Parent Directory Navigation** — ".." entry at the top of every file panel

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  ArchiveManager (actor, singleton)                  │
│  - openArchive() → extracts to /tmp/MiMiNav.../     │
│  - closeArchive() → repacks if dirty                │
│  - cleanup() → called on app exit                   │
│  - sessionForPath() → tracks open archive sessions  │
└─────────────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────────────┐
│  ArchiveNavigationState (per-panel struct)           │
│  - isInsideArchive, archiveURL, archiveTempDir      │
│  - enterArchive(), exitArchive(), isAtArchiveRoot()  │
└─────────────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────────────┐
│  AppState extensions                                 │
│  - leftArchiveState / rightArchiveState              │
│  - enterArchive(at:on:) → open archive in panel     │
│  - exitArchive(on:) → close & repack                │
│  - navigateToParent(on:) → archive-aware ".."       │
└─────────────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────────────┐
│  UI Layer                                            │
│  - FilePanelView: prepends "..", detects archives    │
│  - FileRowView: special icon/color for ".."         │
│  - FileRow: no drag-drop/context menu for ".."      │
│  - FindFilesResultsView: dark blue archive results  │
│  - FindFilesViewModel: goToFile opens archives      │
└─────────────────────────────────────────────────────┘
```

## New Files

| File | Location | Purpose |
|------|----------|---------|
| `ArchiveManager.swift` | `ContextMenu/Services/` | Actor managing extraction, repacking, session tracking |
| `ArchiveNavigationState.swift` | `Primitives/` | Per-panel archive state + extension detection |
| `ParentDirectoryEntry.swift` | `Models/` | Factory for synthetic ".." CustomFile |

## Modified Files

| File | Changes |
|------|---------|
| `CustomFile.swift` | + `isParentEntry`, `isArchiveFile` |
| `AppState.swift` | + archive states, navigation methods, cleanup |
| `FilePanelView.swift` | Archive-aware double-click, ".." prepending |
| `FileRowView.swift` | ".." arrow icon, dark blue coloring |
| `FileRow.swift` | Simplified row container for ".." |
| `FindFilesResultsView.swift` | Dark navy blue for archive results |
| `FindFilesViewModel.swift` | goToFile extracts archives then navigates |

## Flows

### Opening an Archive
```
User double-clicks archive.zip
  → FilePanelView detects ArchiveExtensions.isArchive()
  → AppState.enterArchive(at:on:)
    → ArchiveManager.openArchive() extracts to /tmp/
    → ArchiveNavigationState.enterArchive()
    → Panel navigates to temp directory
```

### Navigating Out of Archive
```
User double-clicks ".." at archive root
  → FilePanelView detects ParentDirectoryEntry
  → AppState.navigateToParent(on:)
    → isAtArchiveRoot() == true
    → AppState.exitArchive(on:)
      → ArchiveManager.closeArchive() repacks if dirty
      → ArchiveNavigationState.exitArchive()
      → Panel navigates to archive's parent directory
```

### Search Result into Archive
```
User double-clicks dark blue result
  → FindFilesViewModel.goToFile(result:appState:)
    → isInsideArchive → ArchiveManager.openArchive()
    → Computes internal path within temp dir
    → Updates panel path, selects the file
```

## Color Scheme

| Element | Color (RGB) |
|---------|-------------|
| Archive search results (name, icon, path) | `(0.1, 0.1, 0.55)` dark navy |
| ".." icon/text inside archive | `(0.2, 0.2, 0.7)` dark blue |
| ".." icon/text in normal dirs | `(0.2, 0.2, 0.7)` dark blue |

## Supported Archive Formats

zip, 7z, tar, gz, bz2, tgz, rar, xz, lzma, lz4, zst
Plus compound: .tar.gz, .tar.bz2, .tar.xz, .tar.lzma, .tar.zst

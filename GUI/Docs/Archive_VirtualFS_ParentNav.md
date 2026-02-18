# Archive Layer — Architecture & Virtual Filesystem

## Date: 18.02.2026
## Status: Refactored

---

## File Structure

| File | Responsibility |
|------|---------------|
| `ArchiveModels.swift` | `ArchiveFormat` enum + `ArchiveSession` struct |
| `ArchiveErrors.swift` | `ArchiveManagerError` — all error cases |
| `ArchiveExtensions.swift` | `ArchiveExtensions` — recognized extension registry |
| `ArchiveProcessSupport.swift` | `ArchiveToolLocator` + `ArchiveProcessRunner` — CLI wrappers |
| `ArchiveExtractor.swift` | Extraction: ZIP / TAR family / 7z |
| `ArchiveRepacker.swift` | Repacking with backup/restore and current timestamps |
| `ArchiveManager.swift` | Session lifecycle: open, close, dirty tracking |
| `ArchiveFormatDetector.swift` | Format detection from file extension |
| `ArchiveNavigationState.swift` | Per-panel state for virtual directory navigation |
| `ArchiveService.swift` | High-level creation API (delegates to ProcessRunner) |

---

## Architecture

```
┌──────────────────────────────────────────┐
│  ArchiveManager (actor, singleton)       │
│  · openArchive()  → extract to /tmp/     │
│  · closeArchive() → repack if dirty      │
│  · isDirty()      → fs change detection  │
│  · cleanup()      → called on app exit   │
└──────────────────────────────────────────┘
         ↕ delegates to
┌────────────────┐   ┌────────────────────┐
│ ArchiveExtractor│   │  ArchiveRepacker   │
│ zip/tar/7z     │   │  zip/tar/7z        │
│ extract only   │   │  repack + backup   │
└────────────────┘   └────────────────────┘
         ↕ both use
┌─────────────────────────────────────────┐
│  ArchiveProcessSupport                  │
│  · ArchiveToolLocator  — finds 7z path  │
│  · ArchiveProcessRunner — async Process │
└─────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────┐
│  ArchiveNavigationState (per-panel)     │
│  · isInsideArchive, archiveURL, tempDir │
│  · enterArchive() / exitArchive()       │
│  · isAtArchiveRoot()                    │
└─────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────┐
│  AppState extensions                    │
│  · enterArchive(at:on:)                 │
│  · exitArchive(on:) — asks to repack    │
│  · navigateToParent(on:)                │
└─────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────┐
│  UI Layer                               │
│  · FilePanelView   — archive open/".."  │
│  · BreadCrumbView  — archive nav        │
│  · FindFilesResultsView — navy results  │
│  · FindFilesViewModel — goToFile        │
└─────────────────────────────────────────┘
```

---

## Key Flows

### Opening an Archive
```
User double-clicks archive.zip
  → FilePanelView detects ArchiveExtensions.isArchive()
  → AppState.enterArchive(at:on:)
    → ArchiveManager.openArchive()
      → ArchiveFormatDetector.detect()
      → ArchiveExtractor.extract() → /tmp/MiMiNavigator_archives/<UUID>/
    → ArchiveNavigationState.enterArchive()
    → Panel path set to temp directory
```

### Exiting an Archive (modified)
```
User clicks ".." at archive root or breadcrumb
  → AppState.exitArchive(on:)
    → ArchiveManager.isDirty() — checks session flag + filesystem scan
    → if dirty: NSAlert "Repack?" shown
      → Repack:   ArchiveRepacker.repack() with current timestamps
      → Discard:  temp dir deleted, no repack
    → ArchiveNavigationState.exitArchive()
    → Panel navigates to archive's parent directory
```

### Repack Behavior
- Original archive permissions (`posixPermissions`) preserved
- `creationDate` and `modificationDate` set to **current time** (archive was modified)
- Backup created before repack; restored automatically on failure; deleted on success

---

## Color Scheme

| Element | Color |
|---------|-------|
| Archive search results | `(0.1, 0.1, 0.55)` dark navy |
| ".." inside archive | `(0.2, 0.2, 0.7)` dark blue |

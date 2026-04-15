<![CDATA[<p align="center">
  <img src="https://raw.githubusercontent.com/senatov/MiMiNavigator/master/GUI/Assets.xcassets/AppIcon.appiconset/128.png" alt="MiMiNavigator" width="96">
</p>

<h2 align="center">MiMiNavigator v0.9.7.2</h2>
<h4 align="center">Dual-panel file manager for macOS · SwiftUI + AppKit</h4>

---

### 🔧 What's new (25 Mar – 01 Apr 2026)

**Network & Remote Files**
- Stabilized FTP/SFTP sessions with public test servers
- Fixed empty panel after FTP disconnect — proper local path restore
- New refresh rules for SFTP remote directories
- Refactored FTP classes and network auth/probing stack
- Fixed MainActor isolation in context menu open-with flow

**Column AutoFit**
- Deferred 3-pass autofit: polls `allSizesResolved` every 500ms
- Size column fallback width (999,99 MB) — no more collapse to 24pt
- Overflow fix + re-fit on window resize >8pt threshold
- Last column flush to right edge — slack compensation
- Content-only sizing (ignore headers), weighted-avg width + 2-char margin

**UI / Navigation**
- Refactored BreadCrumb views — fixed remote/local path navigation
- Pebble shape for parent-entry strip: spring animation, pulsing drop highlight
- Glass-style scroll bar & goto-parent button
- Media preview window (new)
- Drag-and-drop onto subdirs via coordinate lookup
- macOS symlink file handling fix

**Hidden Files**
- Fixed toggle desync + purple `eye.slash` badge for OS-hidden dirs (Library etc)
- Cache key now includes `showHiddenFiles` flag

**Architecture / Clean Code**
- Extracted `ColumnWidthPolicy` enum
- Split multi-type files in ConnectToServer & Network features
- Clean up network stack (auth, probing, share enumeration)
- Migrated ALL settings panes to `~/.mimi/preferences.json`
- Refactored MiMiDefaults + PanelTitleHelper
- Fixed scanning-twice bug, stale UI after rename

**Build & Release**
- `notarize_release.zsh` — full pipeline: build → sign → DMG → notarize → GitHub
- Directory copy from open ZIP file fix

---

**macOS 15+** · **Swift 6.2** · **Strict Concurrency** · **AGPL-3.0**

⬇️ Mount DMG → drag to Applications → done. Notarized, no `xattr -cr` needed.
]]>
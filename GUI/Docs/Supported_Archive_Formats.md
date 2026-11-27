# Supported Archive Formats

## Updated 27.11.2026

---

## Format Categories

### Standard Archives (native macOS tools)
| Extension | Extract | Repack |
|-----------|---------|--------|
| `.zip` | ✅ unzip | ✅ zip |
| `.cbz` | ✅ unzip | ✅ zip |
| `.tar` | ✅ tar | ✅ tar |
| `.tar.gz` / `.tgz` | ✅ tar -z | ✅ tar -z |
| `.tar.bz2` / `.tbz` / `.tbz2` | ✅ tar -j | ✅ tar -j |
| `.tar.xz` / `.txz` | ✅ tar -J | ✅ tar -J |
| `.tar.lzma` / `.tlz` | ✅ tar (auto) | ✅ tar (auto) |
| `.gz` / `.gzip` | ✅ tar -z | ✅ tar -z |
| `.bz2` / `.bzip2` | ✅ tar -j | ✅ tar -j |
| `.xz` | ✅ tar -J | ✅ tar -J |
| `.lzma` | ✅ tar (auto) | ✅ tar (auto) |
| `.Z` | ✅ tar -Z | ✅ tar -Z |

### Modern Compression (tar → fallback to 7z)
| Extension | Extract | Repack |
|-----------|---------|--------|
| `.tar.zst` | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lz4` | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lzo` | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lz` | ✅ tar → 7z | ✅ tar → 7z |
| `.zst` / `.zstd` | ✅ 7z | ✅ 7z |
| `.lz4` | ✅ 7z | ✅ 7z |
| `.lz` / `.lzo` | ✅ 7z | ✅ 7z |

### 7-Zip Native
| Extension | Extract | Repack |
|-----------|---------|--------|
| `.7z` | ✅ 7z | ✅ 7z |

### RAR and Legacy Archives
| Extension | Description | Browse and Extract | Create | Repack |
|-----------|-------------|--------------------|--------|--------|
| `.rar` | RAR archive | `unrar`, `unar`, or `7zz` | `rar` | — |
| `.arc` | ARC archive | `unar` | — | — |
| `.zoo` | ZOO archive | `unar` | — | — |

### Other Formats (via 7z — `brew install sevenzip`)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.cab` | Windows Cabinet | ✅ 7z | ✅ 7z |
| `.arj` | ARJ archive | ✅ 7z | ✅ 7z |
| `.lha` / `.lzh` | LHA/LZH | ✅ 7z | ✅ 7z |
| `.ace` / `.sit` / `.sitx` | Legacy | ✅ 7z | ✅ 7z |
| `.rpm` / `.deb` | Linux packages | ✅ 7z | ✅ 7z |
| `.cpio` / `.xar` | CPIO / XAR | ✅ 7z | ✅ 7z |
| `.wim` / `.swm` | Windows Imaging | ✅ 7z | ✅ 7z |
| `.squashfs` / `.cramfs` | Filesystem images | ✅ 7z | ✅ 7z |
| `.dmg` / `.pkg` | macOS packages | ✅ 7z | ✅ 7z |
| `.jar` / `.war` / `.ear` / `.aar` / `.apk` | Java/Android (ZIP-based) | ✅ 7z | ✅ 7z |
| `.iso` / `.img` / `.vhd` / `.vmdk` | Disk images | ✅ 7z | ✅ 7z |

---

## Dependencies

| Tool | Used For | Source |
|------|----------|--------|
| `/usr/bin/unzip` | ZIP extraction | Built-in macOS |
| `/usr/bin/zip` | ZIP repacking | Built-in macOS |
| `/usr/bin/tar` | TAR family (libarchive) | Built-in macOS |
| `unar` / `lsar` | RAR, ARC and ZOO support | `brew install unar` |
| `rar` / `unrar` | RAR creation and extraction | [RARLAB command-line tools](https://www.rarlab.com/download.htm) |
| `7z` / `7zz` | Everything else | `brew install sevenzip` |

---

## Fallback Strategy

1. ZIP and CBZ use macOS `unzip`. Encrypted archives and unreadable ZIP variants use 7-Zip.
2. TAR uses macOS `tar`, with a retry via 7-Zip if needed.
3. RAR uses the first installed extractor in this order: `unrar`, `unar`, 7-Zip.
4. ARC and ZOO use `unar`. MiMiNavigator offers to install it when opening one of these archives without the tool.
5. Other formats use 7-Zip.

RAR creation appears in the Pack dialog when the `rar` executable is installed in `/opt/homebrew/bin` or `/usr/local/bin`. The Homebrew `rar` cask is disabled.

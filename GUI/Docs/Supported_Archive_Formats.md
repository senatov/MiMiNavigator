# Supported Archive Formats

## Date: 18.02.2026

---

## Format Categories

### Standard Archives (native macOS tools)
| Extension | Extract | Repack |
|-----------|---------|--------|
| `.zip` | ✅ unzip | ✅ zip |
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

### Other Formats (via 7z — `brew install p7zip`)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.rar` | RAR archive | ✅ 7z | ✅ 7z |
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
| `unar` / `lsar` | RAR and legacy archive support | `brew install unar` |
| `7z` | Everything else | `brew install p7zip` |

---

## Fallback Strategy

1. ZIP → `/usr/bin/unzip`
2. TAR family → `/usr/bin/tar` (libarchive auto-detects compression)
3. TAR fails → automatic retry with 7z
4. All others → 7z directly
5. 7z missing → `ArchiveManagerError.toolNotFound` with install hint

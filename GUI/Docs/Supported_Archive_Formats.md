# Supported Archive Formats

## Date: 12.02.2026

---

## Format Categories

### Standard Archives (native macOS tools)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.zip` | ZIP archive | ✅ unzip | ✅ zip |
| `.tar` | TAR (uncompressed) | ✅ tar | ✅ tar |
| `.tar.gz` / `.tgz` | Gzip compressed TAR | ✅ tar -z | ✅ tar -z |
| `.tar.bz2` / `.tbz` / `.tbz2` | Bzip2 compressed TAR | ✅ tar -j | ✅ tar -j |
| `.tar.xz` / `.txz` | XZ compressed TAR | ✅ tar -J | ✅ tar -J |
| `.tar.lzma` / `.tlz` | LZMA compressed TAR | ✅ tar (auto) | ✅ tar (auto) |
| `.gz` / `.gzip` | Gzip single file | ✅ tar -z | ✅ tar -z |
| `.bz2` / `.bzip2` | Bzip2 single file | ✅ tar -j | ✅ tar -j |
| `.xz` | XZ single file | ✅ tar -J | ✅ tar -J |
| `.lzma` | LZMA single file | ✅ tar (auto) | ✅ tar (auto) |
| `.Z` | Unix compress | ✅ tar -Z | ✅ tar -Z |

### Modern Compression (tar + fallback to 7z)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.tar.zst` | Zstandard compressed TAR | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lz4` | LZ4 compressed TAR | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lzo` | LZO compressed TAR | ✅ tar → 7z | ✅ tar → 7z |
| `.tar.lz` | Lzip compressed TAR | ✅ tar → 7z | ✅ tar → 7z |
| `.zst` / `.zstd` | Zstandard single file | ✅ 7z | ✅ 7z |
| `.lz4` | LZ4 single file | ✅ 7z | ✅ 7z |
| `.lz` | Lzip single file | ✅ 7z | ✅ 7z |
| `.lzo` | LZO single file | ✅ 7z | ✅ 7z |

### 7-Zip Native
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.7z` | 7-Zip archive | ✅ 7z | ✅ 7z |

### Other Formats (via 7z — requires `brew install p7zip`)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.rar` | RAR archive | ✅ 7z | ✅ 7z |
| `.cab` | Windows Cabinet | ✅ 7z | ✅ 7z |
| `.arj` | ARJ archive | ✅ 7z | ✅ 7z |
| `.lha` / `.lzh` | LHA/LZH archive | ✅ 7z | ✅ 7z |
| `.ace` | ACE archive | ✅ 7z | ✅ 7z |
| `.sit` / `.sitx` | StuffIt archive | ✅ 7z | ✅ 7z |

### Package / System Formats (via 7z)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.rpm` | Red Hat Package | ✅ 7z | ✅ 7z |
| `.deb` | Debian Package | ✅ 7z | ✅ 7z |
| `.cpio` | CPIO archive | ✅ 7z | ✅ 7z |
| `.xar` | XAR (macOS pkgs) | ✅ 7z | ✅ 7z |
| `.wim` / `.swm` | Windows Imaging | ✅ 7z | ✅ 7z |
| `.squashfs` | SquashFS | ✅ 7z | ✅ 7z |
| `.cramfs` | CramFS | ✅ 7z | ✅ 7z |

### macOS / iOS Specific (via 7z)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.dmg` | Apple Disk Image | ✅ 7z | ✅ 7z |
| `.pkg` | macOS Installer Package | ✅ 7z | ✅ 7z |

### Java / Android (via 7z — these are ZIP-based)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.jar` | Java Archive | ✅ 7z | ✅ 7z |
| `.war` | Web Application Archive | ✅ 7z | ✅ 7z |
| `.ear` | Enterprise Archive | ✅ 7z | ✅ 7z |
| `.aar` | Android Archive | ✅ 7z | ✅ 7z |
| `.apk` | Android Package | ✅ 7z | ✅ 7z |

### Disk Images (via 7z)
| Extension | Description | Extract | Repack |
|-----------|-------------|---------|--------|
| `.iso` | ISO 9660 image | ✅ 7z | ✅ 7z |
| `.img` | Raw disk image | ✅ 7z | ✅ 7z |
| `.vhd` | Virtual Hard Disk | ✅ 7z | ✅ 7z |
| `.vmdk` | VMware Virtual Disk | ✅ 7z | ✅ 7z |

---

## Dependencies

| Tool | Required For | Install |
|------|-------------|---------|
| `/usr/bin/unzip` | ZIP extraction | Built-in macOS |
| `/usr/bin/zip` | ZIP repacking | Built-in macOS |
| `/usr/bin/tar` | TAR family | Built-in macOS (libarchive-based) |
| `7z` | 7z, RAR, CAB, ARJ, RPM, DEB, ISO, DMG, etc. | `brew install p7zip` |

## Fallback Strategy

1. ZIP → native `/usr/bin/unzip`
2. TAR family → native `/usr/bin/tar` (auto-detects compression via libarchive)
3. If tar fails → automatic fallback to 7z
4. Everything else → 7z directly
5. If 7z not installed → error with install instruction

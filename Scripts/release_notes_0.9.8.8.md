# MiMiNavigator v0.9.8.8

## Performance — large directory handling
- **Generic scan timeout (20s)** for all directories, not just `/Volumes/`
- **Adaptive cooldown**: slow dirs get `min(duration×3, 120s)` cooldown instead of 3s
- **Eliminated parasitic `resourceValues` calls** in sort comparator — 19k files: 231s → 13s
- **AutoFit sampling**: max 500 samples for column width measurement (was: all files)
- **Resize↔autofit loop breaker**: `resizePostAutoFitGrace` prevents infinite cycles
- **Cache fallback on timeout**: stale listing served instead of blank panel
- **Task.isCancelled** check every 500 items in scan loop

## Column rendering
- **Canvas-based cell rendering** for text columns — no `…` truncation, hard clip at column edge
- **Name column cap**: autofit limited to 45% of container width; user can drag wider
- **Name truncation**: `.tail` instead of `.middle` — file name beginning always visible
- **childCount default width**: 50 → 56pt

## Scroll behavior
- **Fixed phantom auto-select on scroll**: `navigationScrollPending` guard prevents background refresh from hijacking user scroll position

## Google Drive share links
- **Persistent OAuth token cache**: access/refresh tokens are cached in `~/.mimi/google_drive_token_cache.json`; Keychain is only a fallback
- **Fewer password prompts**: valid cached access tokens are reused until expiration instead of reading Keychain on every share action
- **Blog-friendly image links**: image share links now use `https://lh3.googleusercontent.com/d/<fileID>=s0` instead of Drive preview/download URLs
- **Folder/file fallback order**: folders keep Drive folder URLs, non-image files prefer content links before preview links

## Media info
- **Photo Date vs file dates**: EXIF photo date is shown separately from filesystem `File Created` / `File Modified`
- **OneDrive/cloud date clarity**: local cloud placeholder creation dates no longer look like camera capture dates
- **Spotlight metadata fallback**: sparse JPEGs now show available Spotlight fields such as Date Added, upload state, logical/physical size, pixel count, bit depth, alpha, and orientation

## UI polish
- **Transfer confirmation dialog**: macOS HIG-compliant font hierarchy (13pt bold title, 11pt secondary description, 10pt tertiary paths)
- **Media Convert button**: brighter primary-style Convert button in Media Info panel

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.8.6...v0.9.8.8

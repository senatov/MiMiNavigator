# MiMiNavigator v0.9.8.7

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

## UI polish
- **Transfer confirmation dialog**: macOS HIG-compliant font hierarchy (13pt bold title, 11pt secondary description, 10pt tertiary paths)

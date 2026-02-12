# Find Files UI — Contrast & Readability Improvements

## Date: 12.02.2026
## Status: Applied

---

## Problem

The Find Files dialog was visually "washed out" and hard to read due to excessive use of SwiftUI semantic colors `.secondary`, `.tertiary`, and `.quaternary` which are too faint, especially on macOS with transparency/vibrancy.

## Changes Applied

### FindFilesGeneralTab.swift

| Element | Before | After |
|---------|--------|-------|
| Border color | `(0.75, 0.78, 0.82, 0.5)` | `(0.55, 0.58, 0.65, 0.8)` |
| Border width | `1.0` | `1.2` |
| Field labels | Implicit `.secondary` | `.primary` + `.medium` weight |
| Placeholder text | `.tertiary` | Custom `(0.5, 0.5, 0.55)` |
| Help icon | `.secondary` | Custom `(0.35, 0.35, 0.45)` |
| Field padding | `8h / 6v` | `10h / 7v` |
| Field font | Default | `.system(size: 13)` explicit |
| Options toggles | Default text | `.system(size: 13)` explicit |
| Section headers | Default | `.semibold` + `.primary` |

### FindFilesAdvancedTab.swift

| Element | Before | After |
|---------|--------|-------|
| "From/to" labels | `.secondary` | `.primary` + explicit font |
| "bytes" label | `.tertiary` | Custom `(0.45, 0.47, 0.52)` |
| Section headers | Default | `.semibold` + `.primary` |
| Toggle text | Default | `.system(size: 13)` explicit |
| Info label | `.secondary` / `.callout` | Custom `(0.35, 0.38, 0.45)` / `size: 12` |
| DatePicker labels | Default | `.medium` weight |

### FindFilesWindowContent.swift

| Element | Before | After |
|---------|--------|-------|
| Result count badge | `.subheadline` / `.secondary` | `.medium` weight + accent capsule background |
| Status "Ready" | `.secondary` | Custom `(0.4, 0.45, 0.5)` |
| Status "Searching" | Default | `.primary` |
| Status "Completed" | `.green` | Richer green `(0.15, 0.68, 0.38)` |
| Status bar font | `.caption` | `.system(size: 12, weight: .medium)` |
| Statistics | `.caption2` / `.tertiary` | `size: 11` / Custom `(0.4, 0.42, 0.48)` |

### FindFilesResultsView.swift

| Element | Before | After |
|---------|--------|-------|
| Empty state icon | `.quaternary` | Custom `(0.45, 0.48, 0.55)` + larger size 36 |
| Empty state text | `.secondary` | Custom `(0.35, 0.38, 0.42)` + `.medium` weight |
| Path column (normal) | `.secondary` | Custom `(0.3, 0.32, 0.38)` |
| Match column text | `.secondary` | Custom `(0.25, 0.28, 0.35)` |
| Match dash | `.quaternary` | Custom `(0.6, 0.62, 0.65)` |
| Size column | `.secondary` | Custom `(0.3, 0.32, 0.38)` |
| File icon (normal) | `.secondary` | Custom `(0.35, 0.38, 0.48)` + font 13 |

## Color Palette Summary

| Purpose | RGB | Usage |
|---------|-----|-------|
| Field border | `(0.55, 0.58, 0.65, 0.8)` | Input field outlines |
| Placeholder | `(0.5, 0.5, 0.55)` | TextField prompts |
| Info/help | `(0.35, 0.38, 0.45)` | Help icons, info labels |
| Secondary data | `(0.3, 0.32, 0.38)` | Path, size, match columns |
| Metadata | `(0.4, 0.42, 0.48)` | Statistics, status indicators |
| Archive results | `(0.1, 0.1, 0.55)` | Dark navy for archive entries |
| File icons | `(0.35, 0.38, 0.48)` | Result list file type icons |

## Design Principles

1. **No `.quaternary`** — too invisible, replaced everywhere
2. **Minimal `.tertiary`** — replaced with explicit custom colors
3. **`.secondary` only where appropriate** — most replaced with darker customs
4. **Explicit font sizes** — `13pt` for body, `12pt` for secondary, `11pt` for metadata
5. **Font weights** — `.medium` for labels, `.semibold` for headers, `.regular` for data
6. **`#colorLiteral`** — per project convention for all custom colors

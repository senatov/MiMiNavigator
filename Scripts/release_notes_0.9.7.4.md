# MiMiNavigator v0.9.7.4 — Release Notes

**First notarized release** with fancy DMG installer.

## Highlights

- 🎉 **Notarized by Apple** — no more `xattr -cr` needed, Gatekeeper allows it out of the box
- 📦 **Fancy DMG installer** — background image, drag-to-Applications arrow, standard macOS UX
- 🎬 **Convert Media** — new panel with ffmpeg/ImageIO/Lottie support for 20+ formats
- 🛠️ **External Tools registry** — auto-detect 7z/ffmpeg, install popover, Settings pane
- 🔒 **System permissions** — automatic Full Disk Access and Automation permission onboarding

## New Features

- Convert Media dialog + service (ffmpeg, ImageIO, Lottie), wired to context menu
- External Tools registry with install status, `(i)` popover, Settings pane, SystemSettings deeplinks
- "File Ops" submenu in context menu (cut/copy/paste/duplicate)
- Background panel menu: paste, new folder, new file, copy path, add to favorites
- `⌥ R-Menu` (Option+right-click) shows alternative file type operations
- VLC-based media preview path (migration from AVPlayer)

## Improvements

- AutoFitScheduler singleton — no more per-view column autofit race conditions
- PackDialog → non-modal NSPanel with improved autofit
- DMG/PKG/ISO/JAR → double-click opens with system; archive extraction via R-Menu only
- `.app` bundle copy treats packages as opaque files (no bundle recursion)
- WindowFrameRestorer → poll-based (more reliable)
- Glass hover styling for bottom toolbar buttons
- Third-party license updates (VLC, omaralbeik/VLC)

## Bug Fixes

- APFS firmlink double-click (`/tmp`, `/var`, `/etc`) — uses FileManager fallback
- Archive ZIP/TAR timestamp preservation improved
- Drag-and-drop: ignore same-panel return drops
- Reconnect-on-start disabled after manual remote disconnect
- Startup state restore: cleaner flow, no refresh during termination
- Function access level compilation errors fixed

## Stats

- 30 commits since v0.9.7.3
- Notarized and stapled by Apple notary service

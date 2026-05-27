# MiMiNavigator v0.9.9.4

Media conversion presets and external tool self-repair release.

## Highlights
- **Added**: External Tool Doctor checks optional CLI tools and can repair missing or broken Homebrew dependencies.
- **Added**: Convert Media presets for MP4 H.264/HEVC VideoToolbox, MOV ProRes, MKV H.264, WebM VP9, GIF, image and audio extraction workflows.
- **Added**: IntelliJ IDEA Community/Ultimate detection as a macOS-compatible file and directory compare tool via `idea diff`.
- **Changed**: Media conversion validates FFmpeg codec support before starting and offers install/reinstall when the local FFmpeg build is incomplete.
- **Changed**: Settings and About now document FFmpeg, VideoToolbox and gifski links/license notes.
- **Fixed**: Missing 7-Zip prompts use the shared external tool repair flow.

## Download
Notarized DMG - drag to Applications, no `xattr -cr` needed.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.3...v0.9.9.4

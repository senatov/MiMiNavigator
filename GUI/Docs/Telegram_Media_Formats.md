# Telegram media conversion assessment

## Formats

Telegram static stickers use WebP (or PNG for import). Animated stickers use
gzip-compressed Lottie JSON (`.tgs`). Video stickers use VP9 in WebM without
audio; the longest side is 512 pixels, duration is at most three seconds,
frame rate is at most 30 fps, and the file must fit within 256 KB. TGS files
have a separate 64 KB limit, 512 × 512 canvas, and 60 fps animation.

Sources: [Telegram stickers API](https://core.telegram.org/api/stickers),
[Telegram sticker import](https://core.telegram.org/import-stickers).

## Current implementation

- The Telegram video sticker option for WebM encodes VP9, scales into 512 pixels,
  limits output to 30 fps and three seconds, removes audio, and retries with
  lower quality until the output is within 256,000 bytes. It can also convert
  an existing WebM; give the result a distinct filename.
- TGS input is decompressed with the system `gzip`, then rendered at 15 fps by
  the bundled `TelegramMessenger/rlottie` helper. FFmpeg encodes its BGRA frames
  as GIF, first-frame PNG, MP4, or WebM. Plain Lottie JSON uses the same path.
- WebP still images now use ImageIO to decode the source and `cwebp` to encode
  it. The installed FFmpeg build has no WebP encoder and ImageIO exposes no
  WebP destination type on this Mac. If `cwebp` is missing, conversion gives
  a specific installation instruction (`brew install webp`).
- The Telegram static sticker option requires a source alpha channel, scales
  the longest side to 512 pixels, aims below 512 KB and validates the encoded
  image, dimensions, transparency, and final size. The option also works for
  WebP input, writing a distinct filename by default.

## Bundled renderer

- [TelegramMessenger/rlottie](https://github.com/TelegramMessenger/rlottie)
  is pinned to commit `53c9679069eb6b6513ccc3c892ef4f4a760658da` in
  `Vendor/rlottie`. `Vendor/TelegramRlottieRenderer` builds a separate helper
  executable for each app build. Its source and license files are included in
  the repository; the helper is signed with the app for distribution. The
  vendored CMake file omits examples and the arm64 build uses the portable
  compositor because upstream's 32-bit ARM NEON assembly cannot link on macOS
  arm64. Two C++ files have small current-Clang warning fixes.

Remaining work: Telegram TGS export and validation, plus a bundled WebP encoder
to remove the separate `cwebp` requirement.

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
- TGS input is decompressed with `gzip` and rendered through `python-lottie`
  when available. The FFmpeg fallback cannot reliably render Lottie JSON.
- WebP still images now use ImageIO to decode the source and `cwebp` to encode
  it. The installed FFmpeg build has no WebP encoder and ImageIO exposes no
  WebP destination type on this Mac. If `cwebp` is missing, conversion gives
  a specific installation instruction (`brew install webp`).
- The Telegram static sticker option requires a source alpha channel, scales
  the longest side to 512 pixels, aims below 512 KB and validates the encoded
  image, dimensions, transparency, and final size. The option also works for
  WebP input, writing a distinct filename by default.

## Native library candidates

- [TelegramMessenger/rlottie](https://github.com/TelegramMessenger/rlottie)
  is Telegram's C++14 Lottie renderer. It is a suitable candidate for a local
  C wrapper and Swift package to render TGS frames without Python. Review its
  LGPL 2.1 and bundled component licenses before shipping binaries.
- [Airbnb Lottie for iOS/macOS](https://github.com/airbnb/lottie-ios) is a
  Swift-compatible renderer available through Swift Package Manager. It may
  support native preview, but frame export and TGS decompression still need a
  defined pipeline and tests with real Telegram stickers.
- [LottieViewConvert](https://github.com/SwaggyMacro/LottieViewConvert) is a
  desktop application and useful implementation reference, rather than a
  library to link directly.

Next steps: choose and package a renderer after testing representative TGS
files; offer TGS export with size and content validation. A bundled WebP
library may replace the external `cwebp` requirement in a later release.

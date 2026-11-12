// MediaConversionService+WebP.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import ImageIO

// MARK: - WebP Encoder
enum WebPEncoder {
    static var path: String? {
        ["/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}

// MARK: - WebP Conversion
@MainActor
extension MediaConversionService {
    // MARK: - Encode a still image as WebP
    func runWebPConvert(source: URL, target: URL, options: MediaConversionOptions, panel: ProgressPanel) async throws {
        guard let encoder = WebPEncoder.path else { throw ConversionError.webpEncoderMissing }
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.readFailed(source.lastPathComponent)
        }
        if options.telegramStaticSticker && CGImageSourceGetCount(imageSource) != 1 {
            throw ConversionError.writeFailed("Telegram static stickers need a single-frame image")
        }
        if options.telegramStaticSticker && !hasAlpha(image) {
            throw ConversionError.writeFailed("Telegram static stickers need an image with transparency")
        }
        let intermediate = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi-webp-\(UUID().uuidString)")
            .appendingPathExtension("png")
        defer { try? FileManager.default.removeItem(at: intermediate) }
        guard let destination = CGImageDestinationCreateWithURL(intermediate as CFURL, "public.png" as CFString, 1, nil) else {
            throw ConversionError.writeFailed(intermediate.lastPathComponent)
        }
        let properties = options.preserveImageMetadata
            ? (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] ?? [:])
            : [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.writeFailed(intermediate.lastPathComponent) }
        let quality = Int((options.imageQuality * 100).rounded())
        var arguments = ["-quiet", "-mt", "-q", String(quality), "-metadata", options.preserveImageMetadata ? "all" : "none"]
        if options.telegramStaticSticker {
            arguments += ["-m", "6", "-size", "500000", "-pass", "10"]
            arguments += image.width >= image.height ? ["-resize", "512", "0"] : ["-resize", "0", "512"]
        }
        arguments += [intermediate.path, "-o", target.path]
        panel.appendLine("Encoding WebP with cwebp…")
        try await runProcess(executablePath: encoder, arguments: arguments, panel: panel)
        try validateWebP(target, telegramSticker: options.telegramStaticSticker)
    }

    // MARK: - Check transparency
    func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    // MARK: - Validate the encoded image
    func validateWebP(_ output: URL, telegramSticker: Bool) throws {
        guard let source = CGImageSourceCreateWithURL(output as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              CGImageSourceGetCount(source) == 1 else {
            throw ConversionError.writeFailed("WebP encoder produced an unreadable image")
        }
        guard telegramSticker else { return }
        let size = (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 && size <= 512_000 else { throw ConversionError.writeFailed("Telegram static sticker exceeds 512 KB") }
        guard max(image.width, image.height) == 512 && min(image.width, image.height) <= 512 else {
            throw ConversionError.writeFailed("Telegram static sticker must have one 512 px side")
        }
        guard hasAlpha(image) else {
            throw ConversionError.writeFailed("Telegram static sticker needs transparent pixels; the source may be fully opaque")
        }
    }
}

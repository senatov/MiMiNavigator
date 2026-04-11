// MediaFormat.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Media format definitions and conversion matrix.
//   Maps source extensions to available target formats with tool requirements.

import Foundation

// MARK: - MediaFormat

enum MediaFormat: String, CaseIterable, Identifiable, Hashable {
    // Video
    case mp4
    case mov
    case mkv
    case avi
    case webm
    case gif
    // Image
    case png
    case jpg
    case webp
    case heic
    case tiff
    case bmp
    // Audio
    case mp3
    case aac
    case flac
    case wav
    case ogg
    case m4a
    // Sticker / animation
    case tgs
    // Lottie
    case json

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4: return "MP4 (H.264)"
        case .mov: return "MOV (QuickTime)"
        case .mkv: return "MKV (Matroska)"
        case .avi: return "AVI"
        case .webm: return "WebM (VP9)"
        case .gif: return "GIF (animated)"
        case .png: return "PNG"
        case .jpg: return "JPEG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        case .bmp: return "BMP"
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        case .ogg: return "OGG Vorbis"
        case .m4a: return "M4A (Apple)"
        case .tgs: return "TGS (Telegram sticker)"
        case .json: return "Lottie JSON"
        }
    }

    var fileExtension: String { rawValue }

    var isVideo: Bool {
        [.mp4, .mov, .mkv, .avi, .webm].contains(self)
    }

    var isImage: Bool {
        [.png, .jpg, .webp, .heic, .tiff, .bmp].contains(self)
    }

    var isAudio: Bool {
        [.mp3, .aac, .flac, .wav, .ogg, .m4a].contains(self)
    }

    var isAnimation: Bool {
        [.gif, .tgs, .json].contains(self)
    }

    /// Icon for Picker display
    var systemImage: String {
        if isVideo { return "film" }
        if isImage { return "photo" }
        if isAudio { return "waveform" }
        if isAnimation { return "sparkles" }
        return "doc"
    }

    /// Resolve format from file extension
    static func from(extension ext: String) -> MediaFormat? {
        let lower = ext.lowercased()
        if lower == "jpeg" { return .jpg }
        return MediaFormat(rawValue: lower)
    }

    /// Available target formats for a given source format
    static func targets(for source: MediaFormat) -> [MediaFormat] {
        switch source {
        // Video → video/gif/audio
        case .mp4, .mov, .mkv, .avi:
            return [.mp4, .mov, .mkv, .webm, .gif, .mp3, .aac, .flac, .wav, .m4a]
                .filter { $0 != source }
        case .webm:
            return [.mp4, .mov, .gif, .mp3, .aac, .wav]
        // Image → image/pdf
        case .png, .jpg, .bmp, .tiff:
            return [.png, .jpg, .webp, .heic, .tiff, .bmp, .gif]
                .filter { $0 != source }
        case .webp:
            return [.png, .jpg, .gif, .mp4, .heic, .tiff]
        case .heic:
            return [.png, .jpg, .webp, .tiff]
        // GIF → video/image
        case .gif:
            return [.mp4, .mov, .webm, .png]
        // Audio → audio
        case .mp3, .aac, .flac, .wav, .ogg, .m4a:
            return [.mp3, .aac, .flac, .wav, .ogg, .m4a]
                .filter { $0 != source }
        // Sticker / Lottie
        case .tgs:
            return [.gif, .mp4, .png, .webp]
        case .json:
            return [.gif, .mp4, .png]
        }
    }


    /// Required CLI tool for this conversion
    static func requiredTool(from source: MediaFormat, to target: MediaFormat) -> ConversionTool {
        if source == .tgs { return .lottieAndFFmpeg }
        if source == .json && target != .json { return .lottieAndFFmpeg }
        if source.isImage && target.isImage { return .imageIO }
        if source == .webp || target == .webp { return .ffmpeg }
        return .ffmpeg
    }
}


// MARK: - ConversionTool

enum ConversionTool: String {
    case ffmpeg = "ffmpeg"
    case imageIO = "ImageIO (native)"
    case lottieAndFFmpeg = "Lottie + ffmpeg"

    var isAvailable: Bool {
        switch self {
        case .imageIO: return true
        case .ffmpeg: return FileManager.default.isExecutableFile(atPath: Self.ffmpegPath)
        case .lottieAndFFmpeg:
            return FileManager.default.isExecutableFile(atPath: Self.ffmpegPath)
        }
    }

    static let ffmpegPath: String = {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/ffmpeg"
    }()

    static let gifskiPath: String = {
        let candidates = [
            "/opt/homebrew/bin/gifski",
            "/usr/local/bin/gifski",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/gifski"
    }()
}

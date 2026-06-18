// GifSizeGuard.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Two-pass GIF size guard — ensures output stays under maxBytes.
//   Pass 1: gifski with maxWidth + fps.
//   Pass 2: if still too big — halve fps or shrink to fallbackWidth.

import AppKit
import Foundation


// MARK: - GifSizeGuard

enum GifSizeGuard {

    static let maxBytes: UInt64 = UInt64(19.5 * 1024 * 1024)

    static let initialMaxWidth: Int = 600

    static let initialFPS: Int = 10

    static let fallbackFPS: Int = 5

    static let fallbackWidth: Int = 400

    static let fallbackDurationSeconds: Int = 10

    static let finalFPS: Int = 3

    static let finalWidth: Int = 320

    static let finalDurationSeconds: Int = 6

    static let paletteMaxColors: Int = 256

    static let minFPS: Int = 3

    static let minWidth: Int = 200


    /// Builds gifski CLI arguments with explicit frame file list.
    static func gifskiArguments(
        target: URL,
        framePaths: [String],
        width: Int,
        fps: Int,
        quality: Int = 80
    ) -> [String] {
        var args = [
            "--fps", "\(fps)",
            "--quality", "\(quality)",
            "--width", "\(width)",
            "-o", target.path,
        ]
        args.append(contentsOf: framePaths)
        return args
    }


    /// Builds ffmpeg arguments to extract PNG frames from video.
    static func ffmpegFrameExtractArguments(
        source: URL,
        framePattern: URL,
        fps: Int,
        maxWidth: Int,
        maxDuration: Int? = nil
    ) -> [String] {
        var args = [
            "-hide_banner", "-y",
            "-i", source.path,
            "-vf", "fps=\(fps),scale=\(maxWidth):-1:flags=lanczos"
        ]
        if let maxDuration {
            args += ["-t", "\(maxDuration)"]
        }
        args.append(framePattern.path)
        return args
    }


    /// Builds ffmpeg fallback arguments for direct GIF output (no gifski).
    static func ffmpegDirectGifArguments(
        source: URL,
        target: URL,
        fps: Int,
        maxWidth: Int,
        maxDuration: Int? = nil
    ) -> [String] {
        var args = [
            "-hide_banner", "-y",
            "-i", source.path,
            "-vf", "fps=\(fps),scale=\(maxWidth):-1:flags=lanczos"
        ]
        if let maxDuration {
            args += ["-t", "\(maxDuration)"]
        }
        args += ["-loop", "0", target.path]
        return args
    }

    static func ffmpegReduceExistingGifArguments(
        source: URL,
        target: URL,
        maxDuration: Int,
        fps: Int,
        maxWidth: Int
    ) -> [String] {
        let filter = "fps=\(fps),scale='min(\(maxWidth),iw)':-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=\(paletteMaxColors)[p];[s1][p]paletteuse"
        return [
            "-hide_banner", "-y",
            "-t", "\(maxDuration)",
            "-i", source.path,
            "-filter_complex", filter,
            "-loop", "0",
            target.path,
        ]
    }


    /// Checks if the file at url exceeds maxBytes.
    static func exceedsLimit(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64
        else {
            return false
        }
        return size > maxBytes
    }


    /// Human-readable file size for logging.
    static func fileSizeMB(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64
        else {
            return "?"
        }
        let mb = Double(size) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    // MARK: - User Decision

    @MainActor
    static func promptOversizedGIF(size: String) -> GifSizeDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "GIF Exceeds 19.5 MB"
        alert.informativeText = """
            Generated GIF size is \(size).

            You can keep this file anyway, or let MiMiNavigator regenerate it with shorter duration, lower FPS and smaller dimensions.
            """
        alert.addButton(withTitle: "Reduce Size")
        alert.addButton(withTitle: "Keep Large GIF")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
            case .alertFirstButtonReturn:
                return .reduce
            case .alertSecondButtonReturn:
                return .keep
            default:
                return .cancel
        }
    }
}

// MARK: - GifSizeDecision

enum GifSizeDecision {
    case reduce
    case keep
    case cancel
}

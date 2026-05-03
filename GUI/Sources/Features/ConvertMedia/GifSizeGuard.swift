// GifSizeGuard.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Two-pass GIF size guard — ensures output stays under maxBytes.
//   Pass 1: gifski with maxWidth + fps.
//   Pass 2: if still too big — halve fps or shrink to fallbackWidth.

import Foundation


// MARK: - GifSizeGuard

enum GifSizeGuard {

    static let maxBytes: UInt64 = 19 * 1024 * 1024

    static let initialMaxWidth: Int = 600

    static let initialFPS: Int = 10

    static let fallbackFPS: Int = 5

    static let fallbackWidth: Int = 400

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
        maxWidth: Int
    ) -> [String] {
        [
            "-hide_banner", "-y",
            "-i", source.path,
            "-vf", "fps=\(fps),scale=\(maxWidth):-1:flags=lanczos",
            framePattern.path,
        ]
    }


    /// Builds ffmpeg fallback arguments for direct GIF output (no gifski).
    static func ffmpegDirectGifArguments(
        source: URL,
        target: URL,
        fps: Int,
        maxWidth: Int
    ) -> [String] {
        [
            "-hide_banner", "-y",
            "-i", source.path,
            "-vf", "fps=\(fps),scale=\(maxWidth):-1:flags=lanczos",
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
}

// MediaConversionService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runs media conversions via ffmpeg / ImageIO.
//   Reports progress line-by-line through ProgressPanel.

import AppKit
import Foundation

@MainActor
final class MediaConversionService {
    static let shared = MediaConversionService()
    private init() {}

    /// Main entry — dispatches to correct converter.
    /// Progress reported through ProgressPanel.
    func convert(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        onCancel: @escaping () -> Void
    ) async throws {
        let tool = MediaFormat.requiredTool(from: sourceFormat, to: targetFormat)
        log.info("[MediaConvert] \(sourceFormat.rawValue)→\(targetFormat.rawValue) tool=\(tool.rawValue) src='\(source.lastPathComponent)'")

        guard tool.isAvailable else {
            throw ConversionError.toolMissing(tool.rawValue)
        }

        let panel = ProgressPanel.shared
        panel.show(
            icon: "arrow.triangle.2.circlepath",
            title: "🔄 Convert: \(source.lastPathComponent)",
            status: "→ \(targetFormat.displayName)",
            cancelHandler: onCancel
        )

        do {
            switch tool {
            case .ffmpeg:
                try await runFFmpeg(source: source, target: target, sourceFormat: sourceFormat, targetFormat: targetFormat, panel: panel)
            case .imageIO:
                try await runImageIO(source: source, target: target, targetFormat: targetFormat, panel: panel)
            case .lottieAndFFmpeg:
                try await runLottieConvert(source: source, target: target, targetFormat: targetFormat, panel: panel)
            }
            panel.finish(success: true, message: "✅ Done → \(target.lastPathComponent)")
            log.info("[MediaConvert] success → '\(target.lastPathComponent)'")
        } catch {
            panel.finish(success: false, message: "❌ \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - FFmpeg

    private func runFFmpeg(
        source: URL, target: URL,
        sourceFormat: MediaFormat, targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        var args = ["-hide_banner", "-y", "-i", source.path]
        switch targetFormat {
        case .mp4:
            args += ["-c:v", "libx264", "-preset", "fast", "-crf", "23",
                     "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
        case .mov:
            args += ["-c:v", "prores_ks", "-profile:v", "1", "-c:a", "pcm_s16le"]
        case .mkv:
            args += ["-c:v", "libx264", "-crf", "23", "-c:a", "aac"]
        case .webm:
            args += ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0",
                     "-c:a", "libopus", "-b:a", "128k"]
        case .gif:
            args += ["-vf", "fps=15,scale=640:-1:flags=lanczos",
                     "-loop", "0"]
        case .mp3:
            args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .aac, .m4a:
            args += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        case .flac:
            args += ["-vn", "-c:a", "flac"]
        case .wav:
            args += ["-vn", "-c:a", "pcm_s16le"]
        case .ogg:
            args += ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
        case .png:
            args += ["-frames:v", "1"]
        case .jpg:
            args += ["-frames:v", "1", "-q:v", "2"]
        case .webp:
            args += ["-c:v", "libwebp", "-quality", "85"]
        case .avi:
            args += ["-c:v", "mpeg4", "-q:v", "5", "-c:a", "mp3"]
        default:
            break
        }
        args.append(target.path)
        try await runProcess(
            executablePath: ConversionTool.ffmpegPath,
            arguments: args, panel: panel)
    }

    // MARK: - ImageIO (native macOS)

    private func runImageIO(
        source: URL, target: URL,
        targetFormat: MediaFormat, panel: ProgressPanel
    ) async throws {
        panel.appendLine("Loading image via ImageIO…")
        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw ConversionError.readFailed(source.lastPathComponent)
        }
        let uti = utiForFormat(targetFormat)
        guard let dest = CGImageDestinationCreateWithURL(
            target as CFURL, uti as CFString, 1, nil) else {
            throw ConversionError.writeFailed(target.lastPathComponent)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.writeFailed(target.lastPathComponent)
        }
        panel.appendLine("✅ Image written: \(target.lastPathComponent)")
    }

    private func utiForFormat(_ fmt: MediaFormat) -> String {
        switch fmt {
        case .png:  return "public.png"
        case .jpg:  return "public.jpeg"
        case .tiff: return "public.tiff"
        case .bmp:  return "com.microsoft.bmp"
        case .heic: return "public.heic"
        case .gif:  return "com.compuserve.gif"
        case .webp: return "org.webmproject.webp"
        default:    return "public.png"
        }
    }

    // MARK: - Lottie / TGS

    private func runLottieConvert(
        source: URL, target: URL,
        targetFormat: MediaFormat, panel: ProgressPanel
    ) async throws {
        // TGS = gzipped Lottie JSON
        // step 1: decompress .tgs → .json in /tmp
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi_tgs_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let jsonFile = tmpDir.appendingPathComponent("sticker.json")
        if source.pathExtension.lowercased() == "tgs" {
            panel.appendLine("Decompressing TGS → JSON…")
            let compressed = try Data(contentsOf: source)
            let decompressed = try (compressed as NSData).decompressed(using: .zlib) as Data
            try decompressed.write(to: jsonFile)
        } else {
            try FileManager.default.copyItem(at: source, to: jsonFile)
        }

        // step 2: render frames via lottie_to_gif.sh or ffmpeg
        panel.appendLine("Rendering Lottie frames…")
        if targetFormat == .gif {
            // use gifski path if available for better quality
            let gifskiAvail = FileManager.default.isExecutableFile(
                atPath: ConversionTool.gifskiPath)
            if gifskiAvail {
                let framesDir = tmpDir.appendingPathComponent("frames")
                try FileManager.default.createDirectory(
                    at: framesDir, withIntermediateDirectories: true)
                // render JSON → PNG frames via ffmpeg
                try await runProcess(
                    executablePath: ConversionTool.ffmpegPath,
                    arguments: ["-hide_banner", "-y",
                                "-i", jsonFile.path,
                                "-vf", "fps=15",
                                framesDir.appendingPathComponent("f_%04d.png").path],
                    panel: panel)
                // gifski → high-quality GIF
                try await runProcess(
                    executablePath: ConversionTool.gifskiPath,
                    arguments: ["--fps", "15", "--quality", "90",
                                "-o", target.path,
                                framesDir.appendingPathComponent("f_*.png").path],
                    panel: panel)
            } else {
                // fallback: ffmpeg direct
                try await runProcess(
                    executablePath: ConversionTool.ffmpegPath,
                    arguments: ["-hide_banner", "-y",
                                "-i", jsonFile.path,
                                "-vf", "fps=15,scale=512:-1:flags=lanczos",
                                "-loop", "0", target.path],
                    panel: panel)
            }
        } else {
            // mp4 / png / webp
            try await runProcess(
                executablePath: ConversionTool.ffmpegPath,
                arguments: ["-hide_banner", "-y",
                            "-i", jsonFile.path, target.path],
                panel: panel)
        }
    }

    // MARK: - Process Runner

    private var activeProcess: Process?

    func cancelActiveConversion() {
        activeProcess?.terminate()
        activeProcess = nil
        ProgressPanel.shared.finish(success: false, message: "⏹ Cancelled")
        log.info("[MediaConvert] cancelled by user")
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment

            let stderr = Pipe()
            process.standardError = stderr
            process.standardOutput = Pipe() // discard stdout

            let handle = stderr.fileHandleForReading
            handle.readabilityHandler = { fh in
                guard let line = String(data: fh.availableData, encoding: .utf8),
                      !line.isEmpty else { return }
                Task { @MainActor in
                    for l in line.split(separator: "\n") {
                        panel.appendLine(String(l))
                    }
                }
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                Task { @MainActor in
                    self.activeProcess = nil
                    if proc.terminationStatus == 0 {
                        cont.resume()
                    } else {
                        cont.resume(throwing: ConversionError.processFailed(
                            Int(proc.terminationStatus)))
                    }
                }
            }

            do {
                activeProcess = process
                try process.run()
                panel.appendLine("⚙ \(URL(fileURLWithPath: executablePath).lastPathComponent) \(arguments.joined(separator: " "))")
            } catch {
                activeProcess = nil
                cont.resume(throwing: error)
            }
        }
    }
}

// MARK: - ConversionError

enum ConversionError: LocalizedError {
    case toolMissing(String)
    case readFailed(String)
    case writeFailed(String)
    case processFailed(Int)
    case unsupportedConversion(String, String)

    var errorDescription: String? {
        switch self {
        case .toolMissing(let tool):
            return "Required tool not found: \(tool). Install via: brew install ffmpeg"
        case .readFailed(let name):
            return "Failed to read: \(name)"
        case .writeFailed(let name):
            return "Failed to write: \(name)"
        case .processFailed(let code):
            return "Process exited with code \(code)"
        case .unsupportedConversion(let from, let to):
            return "Conversion \(from) → \(to) is not supported"
        }
    }
}

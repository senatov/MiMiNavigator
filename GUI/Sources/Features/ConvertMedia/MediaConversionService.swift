// MediaConversionService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runs media conversions via ffmpeg / ImageIO.
//   Reports progress line-by-line through ProgressPanel.

import AppKit
import Foundation

// MediaConversionService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runs media conversions via ffmpeg / ImageIO.
//   Reports progress line-by-line through ProgressPanel.

@MainActor
final class MediaConversionService {
    static let shared = MediaConversionService()

    private static let ffmpegBannerArguments = ["-hide_banner", "-y"]
    private static let lottieFrameRate = "15"
    private static let gifScaleFilter = "fps=15,scale=640:-1:flags=lanczos"
    private static let lottiePreviewScaleFilter = "fps=15,scale=512:-1:flags=lanczos"
    private static let webpQuality = "85"
    private static let aacBitrate = "192k"
    private static let opusBitrate = "128k"
    private static let vorbisQuality = "5"
    private static let mp3Quality = "2"
    private static let x264Crf = "23"
    private static let vp9Crf = "30"
    private static let mpeg4Quality = "5"
    private static let gifskiQuality = "90"
    private static let lottieFramesDirectoryName = "frames"
    private static let lottieJSONFileName = "sticker.json"
    private static let lottieFramePattern = "f_%04d.png"

    private var activeProcess: Process?

    private init() {}

    // MARK: - Public API

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
        logStart(source: source, sourceFormat: sourceFormat, targetFormat: targetFormat, tool: tool)

        guard tool.isAvailable else {
            if tool == .gifski {
                return try await handleMissingGifski(
                    source: source,
                    target: target,
                    sourceFormat: sourceFormat,
                    targetFormat: targetFormat,
                    onCancel: onCancel
                )
            }
            throw ConversionError.toolMissing(tool.rawValue)
        }

        let panel = ProgressPanel.shared
        showProgressPanel(panel, source: source, targetFormat: targetFormat, onCancel: onCancel)

        do {
            try await runConversion(
                tool: tool,
                source: source,
                target: target,
                sourceFormat: sourceFormat,
                targetFormat: targetFormat,
                panel: panel
            )
            finishSuccess(panel: panel, target: target)
        } catch {
            finishFailure(panel: panel, error: error)
            throw error
        }
    }

    func cancelActiveConversion() {
        activeProcess?.terminate()
        activeProcess = nil
        ProgressPanel.shared.finish(success: false, message: "⏹ Cancelled")
        log.info("[MediaConvert] cancelled by user")
    }

    // MARK: - Conversion Routing

    private func runConversion(
        tool: ConversionTool,
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        switch tool {
            case .gifski:
                try await runGifskiConvert(
                    source: source,
                    target: target,
                    panel: panel
                )
            case .ffmpeg:
                try await runFFmpeg(
                    source: source,
                    target: target,
                    sourceFormat: sourceFormat,
                    targetFormat: targetFormat,
                    panel: panel
                )
            case .imageIO:
                try await runImageIO(source: source, target: target, targetFormat: targetFormat, panel: panel)
            case .lottieAndFFmpeg:
                try await runLottieConvert(source: source, target: target, targetFormat: targetFormat, panel: panel)
        }
    }

    private func logStart(
        source: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        tool: ConversionTool
    ) {
        log.info(
            "[MediaConvert] \(sourceFormat.rawValue)→\(targetFormat.rawValue) "
                + "tool=\(tool.rawValue) src='\(source.lastPathComponent)'"
        )
    }

    private func showProgressPanel(
        _ panel: ProgressPanel,
        source: URL,
        targetFormat: MediaFormat,
        onCancel: @escaping () -> Void
    ) {
        panel.show(
            icon: "arrow.triangle.2.circlepath",
            title: "🔄 Convert: \(source.lastPathComponent)",
            status: "→ \(targetFormat.displayName)",
            cancelHandler: onCancel
        )
    }

    private func finishSuccess(panel: ProgressPanel, target: URL) {
        panel.finish(success: true, message: "✅ Done → \(target.lastPathComponent)")
        log.info("[MediaConvert] success → '\(target.lastPathComponent)'")
    }

    private func finishFailure(panel: ProgressPanel, error: Error) {
        panel.finish(success: false, message: "❌ \(error.localizedDescription)")
        log.error("[MediaConvert] failed: \(error.localizedDescription)")
    }

    // MARK: - FFmpeg

    private func runFFmpeg(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        let arguments = makeFFmpegArguments(
            source: source,
            target: target,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat
        )

        try await runProcess(
            executablePath: ConversionTool.ffmpegPath,
            arguments: arguments,
            panel: panel
        )
    }

    private func makeFFmpegArguments(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat
    ) -> [String] {
        var arguments = Self.ffmpegBannerArguments
        arguments += ["-i", source.path]
        arguments += ffmpegOutputArguments(sourceFormat: sourceFormat, targetFormat: targetFormat)
        arguments.append(target.path)
        return arguments
    }

    private func ffmpegOutputArguments(
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat
    ) -> [String] {
        switch targetFormat {
            case .mp4:
                return [
                    "-c:v", "libx264",
                    "-preset", "fast",
                    "-crf", Self.x264Crf,
                    "-c:a", "aac",
                    "-b:a", Self.aacBitrate,
                    "-movflags", "+faststart",
                ]

            case .mov:
                return ["-c:v", "prores_ks", "-profile:v", "1", "-c:a", "pcm_s16le"]

            case .mkv:
                return ["-c:v", "libx264", "-crf", Self.x264Crf, "-c:a", "aac"]

            case .webm:
                return [
                    "-c:v", "libvpx-vp9",
                    "-crf", Self.vp9Crf,
                    "-b:v", "0",
                    "-c:a", "libopus",
                    "-b:a", Self.opusBitrate,
                ]

            case .gif:
                return ["-vf", Self.gifScaleFilter, "-loop", "0"]

            case .mp3:
                return ["-vn", "-c:a", "libmp3lame", "-q:a", Self.mp3Quality]

            case .aac, .m4a:
                return ["-vn", "-c:a", "aac", "-b:a", Self.aacBitrate]

            case .flac:
                return ["-vn", "-c:a", "flac"]

            case .wav:
                return ["-vn", "-c:a", "pcm_s16le"]

            case .ogg:
                return ["-vn", "-c:a", "libvorbis", "-q:a", Self.vorbisQuality]

            case .png:
                return ["-frames:v", "1"]

            case .jpg:
                return ["-frames:v", "1", "-q:v", "2"]

            case .webp:
                return ["-c:v", "libwebp", "-quality", Self.webpQuality]

            case .avi:
                return ["-c:v", "mpeg4", "-q:v", Self.mpeg4Quality, "-c:a", "mp3"]

            default:
                if sourceFormat == targetFormat {
                    return []
                }
                return []
        }
    }

    // MARK: - ImageIO

    private func runImageIO(
        source: URL,
        target: URL,
        targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        panel.appendLine("Loading image via ImageIO…")

        let image = try loadImage(from: source)
        let uti = utiForFormat(targetFormat)
        let destination = try makeImageDestination(target: target, uti: uti)

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailed(target.lastPathComponent)
        }

        panel.appendLine("✅ Image written: \(target.lastPathComponent)")
    }

    private func loadImage(from source: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ConversionError.readFailed(source.lastPathComponent)
        }

        return image
    }

    private func makeImageDestination(target: URL, uti: String) throws -> CGImageDestination {
        guard
            let destination = CGImageDestinationCreateWithURL(
                target as CFURL,
                uti as CFString,
                1,
                nil
            )
        else {
            throw ConversionError.writeFailed(target.lastPathComponent)
        }

        return destination
    }

    private func utiForFormat(_ format: MediaFormat) -> String {
        switch format {
            case .png:
                return "public.png"
            case .jpg:
                return "public.jpeg"
            case .tiff:
                return "public.tiff"
            case .bmp:
                return "com.microsoft.bmp"
            case .heic:
                return "public.heic"
            case .gif:
                return "com.compuserve.gif"
            case .webp:
                return "org.webmproject.webp"
            default:
                return "public.png"
        }
    }

    // MARK: - Gifski (high-quality GIF with size guard)

    private func runGifskiConvert(
        source: URL,
        target: URL,
        panel: ProgressPanel
    ) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi_gif_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let framePattern = tempDir.appendingPathComponent("f_%04d.png")

        // pass 1 — initial width + fps
        var width = GifSizeGuard.initialMaxWidth
        var fps = GifSizeGuard.initialFPS

        panel.appendLine("🎬 Extracting frames (\(width)px, \(fps)fps)…")
        try await extractFrames(source: source, framePattern: framePattern, fps: fps, width: width, panel: panel)

        panel.appendLine("🌈 gifski encoding pass 1…")
        try await runGifskiEncode(target: target, framesDir: tempDir, width: width, fps: fps, panel: panel)

        if !GifSizeGuard.exceedsLimit(target) {
            panel.appendLine("✅ GIF size OK: \(GifSizeGuard.fileSizeMB(target))")
            return
        }

        // pass 2 — reduce fps
        panel.appendLine("⚠️ GIF too large (\(GifSizeGuard.fileSizeMB(target))), retrying with \(GifSizeGuard.fallbackFPS)fps…")
        fps = GifSizeGuard.fallbackFPS
        try cleanFrames(in: tempDir)
        try await extractFrames(source: source, framePattern: framePattern, fps: fps, width: width, panel: panel)
        try await runGifskiEncode(target: target, framesDir: tempDir, width: width, fps: fps, panel: panel)

        if !GifSizeGuard.exceedsLimit(target) {
            panel.appendLine("✅ GIF size OK after pass 2: \(GifSizeGuard.fileSizeMB(target))")
            return
        }

        // pass 3 — shrink width
        panel.appendLine("⚠️ Still too large, shrinking to \(GifSizeGuard.fallbackWidth)px…")
        width = GifSizeGuard.fallbackWidth
        try cleanFrames(in: tempDir)
        try await extractFrames(source: source, framePattern: framePattern, fps: fps, width: width, panel: panel)
        try await runGifskiEncode(target: target, framesDir: tempDir, width: width, fps: fps, panel: panel)

        if GifSizeGuard.exceedsLimit(target) {
            let finalSize = GifSizeGuard.fileSizeMB(target)
            panel.appendLine("❌ GIF still \(finalSize) — video may be too long for GIF format")
            log.warning("[GifConvert] exceeded 19MB after 3 passes: \(finalSize)")
            throw ConversionError.gifTooLarge(finalSize)
        }

        panel.appendLine("✅ GIF size OK after pass 3: \(GifSizeGuard.fileSizeMB(target))")
    }


    private func extractFrames(
        source: URL,
        framePattern: URL,
        fps: Int,
        width: Int,
        panel: ProgressPanel
    ) async throws {
        let args = GifSizeGuard.ffmpegFrameExtractArguments(
            source: source,
            framePattern: framePattern,
            fps: fps,
            maxWidth: width
        )
        try await runProcess(executablePath: ConversionTool.ffmpegPath, arguments: args, panel: panel)
    }


    private func runGifskiEncode(
        target: URL,
        framesDir: URL,
        width: Int,
        fps: Int,
        panel: ProgressPanel
    ) async throws {
        try? FileManager.default.removeItem(at: target)
        let frameFiles = try enumerateSortedFrames(in: framesDir)
        guard !frameFiles.isEmpty else {
            throw ConversionError.readFailed("no PNG frames extracted")
        }
        panel.appendLine("⚙ gifski \(frameFiles.count) frames → \(width)px @\(fps)fps")
        let args = GifSizeGuard.gifskiArguments(
            target: target,
            framePaths: frameFiles,
            width: width,
            fps: fps
        )
        try await runProcess(executablePath: ConversionTool.gifskiPath, arguments: args, panel: panel)
    }


    private func cleanFrames(in directory: URL) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in contents where file.pathExtension == "png" {
            try fm.removeItem(at: file)
        }
    }


    private func enumerateSortedFrames(in directory: URL) throws -> [String] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "png" }
            .map(\.path)
            .sorted()
    }


    /// If gifski not installed: prompt user, then fall back to ffmpeg direct GIF.
    private func handleMissingGifski(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        onCancel: @escaping () -> Void
    ) async throws {
        log.warning("[GifConvert] gifski not found, prompting install")
        let userChoseInstall = GifskiInstallAlert.promptInstall()

        if userChoseInstall {
            // user triggered brew install — wait a bit, then retry
            try await Task.sleep(for: .seconds(2))

            if ConversionTool.gifski.isAvailable {
                log.info("[GifConvert] gifski now available after install")
                try await convert(
                    source: source,
                    target: target,
                    sourceFormat: sourceFormat,
                    targetFormat: targetFormat,
                    onCancel: onCancel
                )
                return
            }
        }

        // ffmpeg fallback — direct GIF (lower quality, no size guard)
        log.info("[GifConvert] falling back to ffmpeg direct GIF")
        let panel = ProgressPanel.shared
        showProgressPanel(panel, source: source, targetFormat: targetFormat, onCancel: onCancel)

        do {
            let args = GifSizeGuard.ffmpegDirectGifArguments(
                source: source,
                target: target,
                fps: GifSizeGuard.initialFPS,
                maxWidth: GifSizeGuard.initialMaxWidth
            )
            try await runProcess(executablePath: ConversionTool.ffmpegPath, arguments: args, panel: panel)

            if GifSizeGuard.exceedsLimit(target) {
                panel.appendLine("\u{26A0}\u{FE0F} ffmpeg GIF \(GifSizeGuard.fileSizeMB(target)), retrying smaller\u{2026}")
                let smallerArgs = GifSizeGuard.ffmpegDirectGifArguments(
                    source: source,
                    target: target,
                    fps: GifSizeGuard.fallbackFPS,
                    maxWidth: GifSizeGuard.fallbackWidth
                )
                try await runProcess(executablePath: ConversionTool.ffmpegPath, arguments: smallerArgs, panel: panel)
            }

            finishSuccess(panel: panel, target: target)
        } catch {
            finishFailure(panel: panel, error: error)
            throw error
        }
    }


    // MARK: - Lottie / TGS

    private func runLottieConvert(
        source: URL,
        target: URL,
        targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        let temporaryDirectory = try makeTemporaryLottieDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let jsonFile = temporaryDirectory.appendingPathComponent(Self.lottieJSONFileName)
        try prepareLottieJSON(source: source, destination: jsonFile, panel: panel)

        panel.appendLine("Rendering Lottie frames…")

        if targetFormat == .gif {
            try await runLottieToGIF(jsonFile: jsonFile, target: target, temporaryDirectory: temporaryDirectory, panel: panel)
            return
        }

        try await runGenericLottieExport(jsonFile: jsonFile, target: target, panel: panel)
    }

    private func makeTemporaryLottieDirectory() throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi_tgs_\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        return temporaryDirectory
    }

    private func prepareLottieJSON(
        source: URL,
        destination: URL,
        panel: ProgressPanel
    ) throws {
        if source.pathExtension.lowercased() == "tgs" {
            panel.appendLine("Decompressing TGS → JSON…")
            try decompressTGS(source: source, destination: destination)
            return
        }

        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func decompressTGS(source: URL, destination: URL) throws {
        let compressedData = try Data(contentsOf: source)
        let decompressedData = try (compressedData as NSData).decompressed(using: .zlib) as Data
        try decompressedData.write(to: destination)
    }

    private func runLottieToGIF(
        jsonFile: URL,
        target: URL,
        temporaryDirectory: URL,
        panel: ProgressPanel
    ) async throws {
        if isGifskiAvailable() {
            try await runLottieToGIFViaGifski(
                jsonFile: jsonFile,
                target: target,
                temporaryDirectory: temporaryDirectory,
                panel: panel
            )
            return
        }

        try await runLottieToGIFFallback(jsonFile: jsonFile, target: target, panel: panel)
    }

    private func isGifskiAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: ConversionTool.gifskiPath)
    }

    private func runLottieToGIFViaGifski(
        jsonFile: URL,
        target: URL,
        temporaryDirectory: URL,
        panel: ProgressPanel
    ) async throws {
        let framesDirectory = temporaryDirectory.appendingPathComponent(Self.lottieFramesDirectoryName)
        let framePattern = framesDirectory.appendingPathComponent(Self.lottieFramePattern)

        try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)

        try await runProcess(
            executablePath: ConversionTool.ffmpegPath,
            arguments: makeLottieFrameRenderArguments(jsonFile: jsonFile, framePattern: framePattern),
            panel: panel
        )

        let framePaths = try enumerateSortedFrames(in: framesDirectory)
        guard !framePaths.isEmpty else {
            throw ConversionError.readFailed("no Lottie frames rendered")
        }

        try await runProcess(
            executablePath: ConversionTool.gifskiPath,
            arguments: makeGifskiArguments(target: target, framePaths: framePaths),
            panel: panel
        )
    }

    private func runLottieToGIFFallback(
        jsonFile: URL,
        target: URL,
        panel: ProgressPanel
    ) async throws {
        try await runProcess(
            executablePath: ConversionTool.ffmpegPath,
            arguments: makeLottieGIFFallbackArguments(jsonFile: jsonFile, target: target),
            panel: panel
        )
    }

    private func runGenericLottieExport(
        jsonFile: URL,
        target: URL,
        panel: ProgressPanel
    ) async throws {
        try await runProcess(
            executablePath: ConversionTool.ffmpegPath,
            arguments: Self.ffmpegBannerArguments + ["-i", jsonFile.path, target.path],
            panel: panel
        )
    }

    private func makeLottieFrameRenderArguments(jsonFile: URL, framePattern: URL) -> [String] {
        Self.ffmpegBannerArguments + [
            "-i", jsonFile.path,
            "-vf", "fps=\(Self.lottieFrameRate)",
            framePattern.path,
        ]
    }

    private func makeGifskiArguments(target: URL, framePaths: [String]) -> [String] {
        var args = [
            "--fps", Self.lottieFrameRate,
            "--quality", Self.gifskiQuality,
            "-o", target.path,
        ]
        args.append(contentsOf: framePaths)
        return args
    }

    private func makeLottieGIFFallbackArguments(jsonFile: URL, target: URL) -> [String] {
        Self.ffmpegBannerArguments + [
            "-i", jsonFile.path,
            "-vf", Self.lottiePreviewScaleFilter,
            "-loop", "0",
            target.path,
        ]
    }

    // MARK: - Process Runner

    private func runProcess(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = makeProcess(executablePath: executablePath, arguments: arguments)
            let stderr = Pipe()
            let stdout = Pipe()

            configureProcess(process, stderr: stderr, stdout: stdout)
            installReadabilityHandler(for: stderr.fileHandleForReading, panel: panel)
            installTerminationHandler(for: process, handle: stderr.fileHandleForReading, continuation: continuation)

            do {
                activeProcess = process
                try process.run()
                appendLaunchCommand(executablePath: executablePath, arguments: arguments, panel: panel)
            } catch {
                cleanupAfterLaunchFailure(handle: stderr.fileHandleForReading, error: error, continuation: continuation)
            }
        }
    }

    private func makeProcess(executablePath: String, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        return process
    }

    private func configureProcess(_ process: Process, stderr: Pipe, stdout: Pipe) {
        process.standardError = stderr
        process.standardOutput = stdout
    }

    private func installReadabilityHandler(for handle: FileHandle, panel: ProgressPanel) {
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                let chunk = String(data: data, encoding: .utf8)
            else {
                return
            }

            Task { @MainActor in
                self.appendProcessOutput(chunk, panel: panel)
            }
        }
    }

    private func appendProcessOutput(_ chunk: String, panel: ProgressPanel) {
        for line in chunk.split(separator: "\n") {
            panel.appendLine(String(line))
        }
    }

    private func installTerminationHandler(
        for process: Process,
        handle: FileHandle,
        continuation: CheckedContinuation<Void, Error>
    ) {
        process.terminationHandler = { process in
            handle.readabilityHandler = nil

            Task { @MainActor in
                self.activeProcess = nil

                if process.terminationReason == .uncaughtSignal,
                    process.terminationStatus == SIGTERM
                {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                if process.terminationStatus == 0 {
                    continuation.resume()
                    return
                }

                continuation.resume(
                    throwing: ConversionError.processFailed(Int(process.terminationStatus))
                )
            }
        }
    }

    private func appendLaunchCommand(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel
    ) {
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        let commandLine = arguments.joined(separator: " ")
        panel.appendLine("⚙ \(executableName) \(commandLine)")
    }

    private func cleanupAfterLaunchFailure(
        handle: FileHandle,
        error: Error,
        continuation: CheckedContinuation<Void, Error>
    ) {
        handle.readabilityHandler = nil
        activeProcess = nil
        continuation.resume(throwing: error)
    }
}



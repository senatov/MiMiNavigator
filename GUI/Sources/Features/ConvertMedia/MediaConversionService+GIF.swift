// MediaConversionService+GIF.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: GIF conversion helpers for MediaConversionService.

import FileModelKit
import Foundation

// MARK: - GIF Conversion

@MainActor
extension MediaConversionService {
    func runGifskiConvert(
        source: URL,
        target: URL,
        panel: ProgressPanel
    ) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi_gif_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let framePattern = tempDir.appendingPathComponent("f_%04d.png")
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
        panel.appendLine("⚠️ GIF too large (\(GifSizeGuard.fileSizeMB(target))), retrying with \(GifSizeGuard.fallbackFPS)fps…")
        fps = GifSizeGuard.fallbackFPS
        try cleanFrames(in: tempDir)
        try await extractFrames(source: source, framePattern: framePattern, fps: fps, width: width, panel: panel)
        try await runGifskiEncode(target: target, framesDir: tempDir, width: width, fps: fps, panel: panel)
        if !GifSizeGuard.exceedsLimit(target) {
            panel.appendLine("✅ GIF size OK after pass 2: \(GifSizeGuard.fileSizeMB(target))")
            return
        }
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

    func extractFrames(
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

    func runGifskiEncode(
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

    func cleanFrames(in directory: URL) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in contents where file.pathExtension == "png" {
            try fm.removeItem(at: file)
        }
    }

    func enumerateSortedFrames(in directory: URL) throws -> [String] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "png" }
            .map(\.path)
            .sorted()
    }

    func handleMissingGifski(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        onCancel: @escaping () -> Void
    ) async throws {
        log.warning("[GifConvert] gifski not found, prompting install")
        let userChoseInstall = GifskiInstallAlert.promptInstall()
        if userChoseInstall {
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
}

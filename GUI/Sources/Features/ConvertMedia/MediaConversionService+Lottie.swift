// MediaConversionService+Lottie.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Lottie and TGS conversion helpers for MediaConversionService.

import FileModelKit
import Foundation

// MARK: - Lottie / TGS

@MainActor
extension MediaConversionService {
    func runLottieConvert(
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
        if let lottieConvertPath = ExternalToolCatalog.lottieConvert.resolvedPath {
            try await runLottieConvertCLI(
                executablePath: lottieConvertPath,
                jsonFile: jsonFile,
                target: target,
                targetFormat: targetFormat,
                panel: panel
            )
            return
        }
        if targetFormat == .gif {
            do {
                try await runLottieToGIF(jsonFile: jsonFile, target: target, temporaryDirectory: temporaryDirectory, panel: panel)
            } catch {
                try await handleMissingLottieConvert(error: error)
            }
            return
        }
        do {
            try await runGenericLottieExport(jsonFile: jsonFile, target: target, panel: panel)
        } catch {
            try await handleMissingLottieConvert(error: error)
        }
    }

    func makeTemporaryLottieDirectory() throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimi_tgs_\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        return temporaryDirectory
    }

    func prepareLottieJSON(
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

    func decompressTGS(source: URL, destination: URL) throws {
        let gzipPath = ExternalToolCatalog.gzip.resolvedPath ?? "/usr/bin/gzip"
        let process = Process()
        let errorOutput = Pipe()
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        process.executableURL = URL(fileURLWithPath: gzipPath)
        process.arguments = ["-dc", source.path]
        process.standardOutput = output
        process.standardError = errorOutput
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 || isEmptyFile(destination) {
            let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? source.lastPathComponent
            throw ConversionError.readFailed(message)
        }
    }

    func isEmptyFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64
        else {
            return true
        }
        return size == 0
    }

    func runLottieConvertCLI(
        executablePath: String,
        jsonFile: URL,
        target: URL,
        targetFormat: MediaFormat,
        panel: ProgressPanel
    ) async throws {
        let args = makeLottieConvertArguments(jsonFile: jsonFile, target: target, targetFormat: targetFormat)
        try await runProcess(executablePath: executablePath, arguments: args, panel: panel)
        if targetFormat == .gif && GifSizeGuard.exceedsLimit(target) {
            try await handleOversizedLottieGIF(
                executablePath: executablePath,
                jsonFile: jsonFile,
                target: target,
                panel: panel
            )
        }
    }

    func makeLottieConvertArguments(
        jsonFile: URL,
        target: URL,
        targetFormat: MediaFormat,
        fps: Int = GifSizeGuard.initialFPS,
        width: Int = GifSizeGuard.initialMaxWidth
    ) -> [String] {
        if targetFormat == .gif {
            return ["--fps", "\(fps)", "--width", "\(width)", jsonFile.path, target.path]
        }
        return [jsonFile.path, target.path]
    }

    func handleOversizedLottieGIF(
        executablePath: String,
        jsonFile: URL,
        target: URL,
        panel: ProgressPanel
    ) async throws {
        let firstPassSize = GifSizeGuard.fileSizeMB(target)
        panel.appendLine("⚠️ GIF too large: \(firstPassSize)")
        switch GifSizeGuard.promptOversizedGIF(size: firstPassSize) {
            case .keep:
                panel.appendLine("Keeping GIF above 19.5 MB by user choice")
                return
            case .cancel:
                throw CancellationError()
            case .reduce:
                panel.appendLine("Regenerating smaller Lottie GIF…")
        }
        var args = makeLottieConvertArguments(
            jsonFile: jsonFile,
            target: target,
            targetFormat: .gif,
            fps: GifSizeGuard.fallbackFPS,
            width: GifSizeGuard.fallbackWidth
        )
        try await runProcess(executablePath: executablePath, arguments: args, panel: panel)
        if GifSizeGuard.exceedsLimit(target) {
            args = makeLottieConvertArguments(
                jsonFile: jsonFile,
                target: target,
                targetFormat: .gif,
                fps: GifSizeGuard.finalFPS,
                width: GifSizeGuard.finalWidth
            )
            try await runProcess(executablePath: executablePath, arguments: args, panel: panel)
        }
        if GifSizeGuard.exceedsLimit(target) {
            throw ConversionError.gifTooLarge(GifSizeGuard.fileSizeMB(target))
        }
    }

    func handleMissingLottieConvert(error: Error) async throws {
        guard error is ConversionError else { throw error }
        _ = await ExternalToolDoctor.shared.ensureReady(
            toolID: ExternalToolCatalog.lottieConvert.id,
            context: "TGS and Lottie conversion needs python-lottie when ffmpeg cannot render Lottie JSON."
        )
        throw ConversionError.lottieToolMissing
    }

    func runLottieToGIF(
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

    func isGifskiAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: ConversionTool.gifskiPath)
    }

    func runLottieToGIFViaGifski(
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

    func runLottieToGIFFallback(
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

    func runGenericLottieExport(
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

    func makeLottieFrameRenderArguments(jsonFile: URL, framePattern: URL) -> [String] {
        Self.ffmpegBannerArguments + [
            "-i", jsonFile.path,
            "-vf", "fps=\(Self.lottieFrameRate)",
            framePattern.path,
        ]
    }

    func makeGifskiArguments(target: URL, framePaths: [String]) -> [String] {
        var args = [
            "--fps", Self.lottieFrameRate,
            "--quality", Self.gifskiQuality,
            "-o", target.path,
        ]
        args.append(contentsOf: framePaths)
        return args
    }

    func makeLottieGIFFallbackArguments(jsonFile: URL, target: URL) -> [String] {
        Self.ffmpegBannerArguments + [
            "-i", jsonFile.path,
            "-vf", Self.lottiePreviewScaleFilter,
            "-loop", "0",
            target.path,
        ]
    }
}

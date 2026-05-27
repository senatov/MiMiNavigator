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
        if targetFormat == .gif {
            try await runLottieToGIF(jsonFile: jsonFile, target: target, temporaryDirectory: temporaryDirectory, panel: panel)
            return
        }
        try await runGenericLottieExport(jsonFile: jsonFile, target: target, panel: panel)
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
        let compressedData = try Data(contentsOf: source)
        let decompressedData = try (compressedData as NSData).decompressed(using: .zlib) as Data
        try decompressedData.write(to: destination)
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

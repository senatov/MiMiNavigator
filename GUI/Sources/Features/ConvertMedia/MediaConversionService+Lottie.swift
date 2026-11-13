// MediaConversionService+Lottie.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Telegram rlottie rendering for TGS and Lottie JSON conversion.

import ExternalToolsKit
import FileModelKit
import Foundation

// MARK: - Lottie / TGS
@MainActor
extension MediaConversionService {
    func runLottieConvert(source: URL, target: URL, targetFormat: MediaFormat, panel: ProgressPanel) async throws {
        let temporaryDirectory = try makeTemporaryLottieDirectory()
        defer { recycleConversionArtifactLater(temporaryDirectory) }
        let jsonFile = temporaryDirectory.appendingPathComponent(Self.lottieJSONFileName)
        try await prepareLottieJSON(source: source, destination: jsonFile, panel: panel)
        guard let helper = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("mimi-rlottie-render"), FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw ConversionError.lottieToolMissing
        }
        let rawFrames = temporaryDirectory.appendingPathComponent("frames.bgra")
        panel.appendLine("Rendering frames with TelegramMessenger/rlottie…")
        try await runProcess(executablePath: helper.path, arguments: [jsonFile.path, rawFrames.path, Self.lottieFrameRate], panel: panel)
        guard !isEmptyFile(rawFrames) else { throw ConversionError.readFailed("no Lottie frames rendered") }
        let input = Self.ffmpegBannerArguments + ["-f", "rawvideo", "-pixel_format", "bgra", "-video_size", "512x512", "-framerate", Self.lottieFrameRate, "-i", rawFrames.path]
        let output: [String]
        switch targetFormat {
        case .gif:
            output = ["-filter_complex", "[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=alpha_threshold=128", "-loop", "0"]
        case .png:
            output = ["-frames:v", "1", "-update", "1"]
        case .mp4:
            output = ["-vf", "format=yuv420p", "-an", "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart"]
        case .webm:
            output = ["-an", "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-auto-alt-ref", "0", "-b:v", "0", "-crf", "35"]
        default:
            throw ConversionError.unsupportedConversion(source.pathExtension, targetFormat.fileExtension)
        }
        try await runProcess(executablePath: ConversionTool.ffmpegPath, arguments: input + output + [target.path], panel: panel)
    }

    // MARK: - Temporary animation workspace
    func makeTemporaryLottieDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mimi_tgs_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - Prepare JSON source
    func prepareLottieJSON(source: URL, destination: URL, panel: ProgressPanel) async throws {
        if source.pathExtension.lowercased() == "tgs" {
            panel.appendLine("Decompressing TGS → JSON…")
            let gzip = ExternalToolCatalog.gzip.resolvedPath ?? "/usr/bin/gzip"
            try await runProcess(executablePath: gzip, arguments: ["-dc", source.path], panel: panel, outputFile: destination)
            if isEmptyFile(destination) { throw ConversionError.readFailed(source.lastPathComponent) }
            return
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    // MARK: - Check rendered output
    func isEmptyFile(_ url: URL) -> Bool {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? UInt64 else { return true }
        return size == 0
    }
}

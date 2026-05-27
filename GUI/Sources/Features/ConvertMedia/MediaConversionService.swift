// MediaConversionService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runs media conversions via ffmpeg / ImageIO.
//   Reports progress line-by-line through ProgressPanel.

import AppKit
import FileModelKit
import Foundation

@MainActor
final class MediaConversionService {
    static let shared = MediaConversionService()

    static let ffmpegBannerArguments = ["-hide_banner", "-y"]
    static let lottieFrameRate = "15"
    static let lottiePreviewScaleFilter = "fps=15,scale=512:-1:flags=lanczos"
    static let gifskiQuality = "90"
    static let lottieFramesDirectoryName = "frames"
    static let lottieJSONFileName = "sticker.json"
    static let lottieFramePattern = "f_%04d.png"

    var activeProcess: Process?

    private init() {}

    // MARK: - Public API

    /// Main entry — dispatches to correct converter.
    /// Progress reported through ProgressPanel.
    func convert(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        preset: MediaConversionPreset? = nil,
        onCancel: @escaping () -> Void
    ) async throws {
        let conversionPreset = preset ?? MediaConversionPreset.defaultPreset(for: sourceFormat, target: targetFormat)
        let tool = resolvedTool(sourceFormat: sourceFormat, targetFormat: targetFormat, preset: conversionPreset)
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
                preset: conversionPreset,
                panel: panel
            )
            finishSuccess(panel: panel, target: target)
        } catch {
            finishFailure(panel: panel, error: error)
            throw error
        }
    }

    func resolvedTool(
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        preset: MediaConversionPreset?
    ) -> ConversionTool {
        if sourceFormat == .tgs || sourceFormat == .json {
            return MediaFormat.requiredTool(from: sourceFormat, to: targetFormat)
        }
        return preset?.requiredTool ?? MediaFormat.requiredTool(from: sourceFormat, to: targetFormat)
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
        preset: MediaConversionPreset?,
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
                    preset: preset,
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

    func showProgressPanel(
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

    func finishSuccess(panel: ProgressPanel, target: URL) {
        panel.finish(success: true, message: "✅ Done → \(target.lastPathComponent)")
        log.info("[MediaConvert] success → '\(target.lastPathComponent)'")
    }

    func finishFailure(panel: ProgressPanel, error: Error) {
        panel.finish(success: false, message: "❌ \(error.localizedDescription)")
        log.error("[MediaConvert] failed: \(error.localizedDescription)")
    }

    // MARK: - FFmpeg

    private func runFFmpeg(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        preset: MediaConversionPreset?,
        panel: ProgressPanel
    ) async throws {
        let arguments = makeFFmpegArguments(
            source: source,
            target: target,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
            preset: preset
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
        targetFormat: MediaFormat,
        preset: MediaConversionPreset?
    ) -> [String] {
        var arguments = Self.ffmpegBannerArguments
        arguments += ["-i", source.path]
        if let preset {
            arguments += preset.ffmpegOutputArguments(sourceFormat: sourceFormat)
        } else {
            arguments += MediaFormat.requiredFFmpegArguments(sourceFormat: sourceFormat, targetFormat: targetFormat)
        }
        arguments.append(target.path)
        return arguments
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

}

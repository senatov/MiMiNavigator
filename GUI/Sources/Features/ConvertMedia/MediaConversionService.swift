// MediaConversionService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runs media conversions via ffmpeg / ImageIO.
//   Reports progress line-by-line through ProgressPanel.

import AppKit
import ExternalToolsKit
import FileModelKit
import Foundation
import Observation

@MainActor
@Observable
final class MediaConversionService {
    static let shared = MediaConversionService()

    static let ffmpegBannerArguments = ["-hide_banner", "-nostdin", "-y"]
    static let lottieFrameRate = "15"
    static let lottiePreviewScaleFilter = "fps=15,scale=512:-1:flags=lanczos"
    static let gifskiQuality = "90"
    static let lottieFramesDirectoryName = "frames"
    static let lottieJSONFileName = "sticker.json"
    static let lottieFramePattern = "f_%04d.png"
    static let telegramVideoStickerArguments = [
        "-map", "0:v:0", "-an", "-sn", "-dn",
        "-vf", "fps=30,scale=512:512:force_original_aspect_ratio=decrease:force_divisible_by=2,format=yuva420p",
        "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-auto-alt-ref", "0",
        "-crf", "40", "-b:v", "0", "-deadline", "good", "-cpu-used", "4",
    ]

    var activeProcess: Process?
    private var conversionInFlight = false
    var approvedOversizedGIFTargets: Set<String> = []
    private(set) var phase: MediaConversionPhase = .idle

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
        options: MediaConversionOptions = MediaConversionOptions(),
        onCancel: @escaping () -> Void
    ) async throws -> URL {
        guard !conversionInFlight else { throw ConversionError.conversionAlreadyRunning }
        if options.telegramVideoSticker && (targetFormat != .webm || !(sourceFormat.isVideo || sourceFormat == .gif)) {
            throw ConversionError.writeFailed("Telegram video sticker needs video or GIF input and WebM output")
        }
        try Self.validateDestination(source: source, target: target)
        conversionInFlight = true
        defer { conversionInFlight = false }
        let destination = try await resolveDestination(source: source, requested: target)
        let replaceExisting = FileManager.default.fileExists(atPath: destination.path)
        let staged = stagedOutputURL(for: destination)
        defer { try? FileManager.default.removeItem(at: staged) }
        let operationID = UUID().uuidString
        let started = ContinuousClock.now
        log.info("[MediaConvert] id=\(operationID) begin source=\(source.path.debugDescription) target=\(destination.path.debugDescription)")
        MemoryDiagnostics.shared.checkpoint("convert.before.\(operationID)")
        defer {
            log.info("[MediaConvert] id=\(operationID) end elapsed=\(started.duration(to: .now)) phase=\(phase)")
            MemoryDiagnostics.shared.checkpoint("convert.after.\(operationID)")
        }
        let conversionPreset = preset ?? MediaConversionPreset.defaultPreset(for: sourceFormat, target: targetFormat)
        let requestedTool = resolvedTool(sourceFormat: sourceFormat, targetFormat: targetFormat, preset: conversionPreset)
        var executionTool = requestedTool
        logStart(source: source, sourceFormat: sourceFormat, targetFormat: targetFormat, tool: requestedTool)
        approvedOversizedGIFTargets.remove(staged.path)
        defer { approvedOversizedGIFTargets.remove(staged.path) }
        phase = .preparing
        let toolReady = await ExternalToolDoctor.shared.ensureReady(
            conversionTool: requestedTool,
            context: "Media conversion needs \(requestedTool.rawValue) for \(sourceFormat.rawValue) → \(targetFormat.rawValue)."
        )
        if !toolReady, requestedTool == .gifski, ConversionTool.ffmpeg.isAvailable {
            executionTool = .ffmpeg
            log.info("[MediaConvert] gifski unavailable after repair flow; using ffmpeg fallback")
        } else if !toolReady {
            let error = ConversionError.toolMissing(requestedTool.rawValue)
            phase = .failed(message: error.localizedDescription)
            throw error
        }
        let panel = ProgressPanel.shared
        guard phase != .cancelled else { throw CancellationError() }
        showProgressPanel(panel, source: source, targetFormat: targetFormat, onCancel: onCancel)
        phase = .running(tool: executionTool.rawValue)
        do {
            try await runConversion(
                tool: executionTool,
                source: source,
                target: staged,
                sourceFormat: sourceFormat,
                targetFormat: targetFormat,
                preset: conversionPreset,
                options: options,
                panel: panel
            )
            guard phase != .cancelled else { throw CancellationError() }
            if targetFormat == .gif && options.gifSizeLimitEnabled { try await enforceGIFLimit(target: staged, panel: panel) }
            try installStagedOutput(staged, at: destination, replaceExisting: replaceExisting)
            finishSuccess(panel: panel, target: destination)
            phase = .completed(output: destination)
            return destination
        } catch is CancellationError {
            phase = .cancelled
            panel.finish(success: false, message: "⏹ Cancelled")
            throw CancellationError()
        } catch {
            finishFailure(panel: panel, error: error)
            phase = .failed(message: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Destination safety
    nonisolated static func validateDestination(source: URL, target: URL) throws {
        let sourcePath = source.standardizedFileURL.resolvingSymlinksInPath().path
        let targetPath = target.standardizedFileURL.resolvingSymlinksInPath().path
        guard sourcePath != targetPath else { throw ConversionError.sameSourceAndTarget }
        let sourceInfo = try? FileManager.default.attributesOfItem(atPath: sourcePath)
        let targetInfo = try? FileManager.default.attributesOfItem(atPath: targetPath)
        if let sourceInfo, let targetInfo,
           let sourceInode = sourceInfo[.systemFileNumber] as? NSNumber,
           let targetInode = targetInfo[.systemFileNumber] as? NSNumber,
           sourceInode == targetInode,
           let sourceDevice = sourceInfo[.systemNumber] as? NSNumber,
           let targetDevice = targetInfo[.systemNumber] as? NSNumber,
           sourceDevice == targetDevice {
            throw ConversionError.sameSourceAndTarget
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
        guard phase.isActive else { return }
        activeProcess?.terminate()
        phase = .cancelled
        ProgressPanel.shared.finish(success: false, message: "⏹ Cancelled")
        log.info("[MediaConvert] cancelled by user")
    }

    // MARK: - User Decision
    func requestOversizedGIFDecision(size: String) async -> GifSizeDecision {
        let previousPhase = phase
        phase = .awaitingDecision(reason: "GIF size is \(size)")
        let decision = await GifSizeGuard.promptOversizedGIF(size: size)
        guard phase != .cancelled else { return .cancel }
        phase = previousPhase
        return decision
    }

    // MARK: - Conversion Routing

    private func runConversion(
        tool: ConversionTool,
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        preset: MediaConversionPreset?,
        options: MediaConversionOptions,
        panel: ProgressPanel
    ) async throws {
        switch tool {
            case .gifski:
                try await runGifskiConvert(
                    source: source,
                    target: target,
                    enforceSizeLimit: options.gifSizeLimitEnabled,
                    clipStartSeconds: options.clipStartSeconds,
                    clipDurationSeconds: options.clipDurationSeconds,
                    panel: panel
                )
            case .ffmpeg:
                try await runFFmpeg(
                    source: source,
                    target: target,
                    sourceFormat: sourceFormat,
                    targetFormat: targetFormat,
                    preset: preset,
                    options: options,
                    panel: panel
                )
            case .imageIO:
                try await runImageIO(source: source, target: target, targetFormat: targetFormat, options: options, panel: panel)
            case .lottieAndFFmpeg:
                try await runLottieConvert(source: source, target: target, targetFormat: targetFormat, enforceSizeLimit: options.gifSizeLimitEnabled, panel: panel)
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
        options: MediaConversionOptions,
        panel: ProgressPanel
    ) async throws {
        let sourceDuration = await probeDuration(of: source, panel: panel)
        let remainingDuration = sourceDuration.map { max(0, $0 - (options.clipStartSeconds ?? 0)) }
        let duration = [remainingDuration, options.clipDurationSeconds, options.telegramVideoSticker ? 3 : nil].compactMap { $0 }.min()
        panel.updateProgress(duration == nil || duration == 0 ? nil : 0)
        let stickerQualities: [Int?] = options.telegramVideoSticker ? [40, 48, 56] : [nil]
        for quality in stickerQualities {
            let arguments = makeFFmpegArguments(
                source: source, target: target, sourceFormat: sourceFormat,
                targetFormat: targetFormat, preset: preset, options: options,
                stickerQuality: quality
            )
            try await runProcess(executablePath: ConversionTool.ffmpegPath, arguments: arguments, panel: panel, progressDuration: duration == 0 ? nil : duration)
            guard options.telegramVideoSticker else { return }
            let size = (try FileManager.default.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.intValue ?? 0
            if size > 0 && size <= 256_000 { return }
            panel.appendLine("Telegram sticker is \(size) bytes; retrying at lower quality…")
            try FileManager.default.removeItem(at: target)
        }
        throw ConversionError.writeFailed("Telegram video sticker exceeds 256 KB even at reduced quality")
    }

    private func makeFFmpegArguments(
        source: URL,
        target: URL,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        preset: MediaConversionPreset?,
        options: MediaConversionOptions,
        stickerQuality: Int? = nil
    ) -> [String] {
        var arguments = Self.ffmpegBannerArguments + ["-nostats", "-progress", "pipe:1"]
        if let start = options.clipStartSeconds { arguments += ["-ss", String(start)] }
        arguments += ["-i", source.path]
        if options.telegramVideoSticker {
            arguments += Self.telegramVideoStickerArguments
        } else if let preset {
            arguments += preset.ffmpegOutputArguments(sourceFormat: sourceFormat)
        } else {
            arguments += MediaFormat.requiredFFmpegArguments(sourceFormat: sourceFormat, targetFormat: targetFormat)
        }
        if targetFormat == .webp && sourceFormat.isImage {
            arguments += ["-quality", "\(Int((options.imageQuality * 100).rounded()))"]
        }
        if options.telegramVideoSticker, let stickerQuality, let crfIndex = arguments.firstIndex(of: "-crf") {
            arguments[crfIndex + 1] = String(stickerQuality)
        }
        if options.telegramVideoSticker {
            arguments += ["-t", String(min(options.clipDurationSeconds ?? 3, 3))]
        } else if let duration = options.clipDurationSeconds {
            arguments += ["-t", String(duration)]
        }
        arguments.append(target.path)
        return arguments
    }

    // MARK: - ImageIO

    private func runImageIO(
        source: URL,
        target: URL,
        targetFormat: MediaFormat,
        options: MediaConversionOptions,
        panel: ProgressPanel
    ) async throws {
        panel.appendLine("Loading image via ImageIO…")

        let imageSource = try loadImageSource(from: source)
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.readFailed(source.lastPathComponent)
        }
        let uti = utiForFormat(targetFormat)
        let destination = try makeImageDestination(target: target, uti: uti)
        var properties = options.preserveImageMetadata
            ? (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] ?? [:])
            : [:]
        if targetFormat == .jpg || targetFormat == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(options.imageQuality, 0.01), 1)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailed(target.lastPathComponent)
        }

        panel.appendLine("✅ Image written: \(target.lastPathComponent)")
    }

    private func loadImageSource(from source: URL) throws -> CGImageSource {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw ConversionError.readFailed(source.lastPathComponent)
        }
        return imageSource
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

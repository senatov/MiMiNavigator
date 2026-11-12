// CntMenuCoord+MediaConvert.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Media conversion dispatch from context menu coordinator

import FileModelKit
import Foundation

extension CntMenuCoord {

    /// Runs media conversion via MediaConversionService with ProgressPanel feedback.
    func performMediaConversion(
        file: CustomFile,
        targetFormat: MediaFormat,
        outputURL: URL,
        panel: FavPanelSide,
        appState: AppState,
        preset: MediaConversionPreset? = nil,
        options: MediaConversionOptions = MediaConversionOptions(),
        deleteOriginal: Bool = false
    ) async {
        guard let sourceFormat = resolveSourceFormat(for: file) else { return }

        logMediaConversionStart(file: file, sourceFormat: sourceFormat, targetFormat: targetFormat)
        isProcessing = true
        defer { finishMediaConversionProcessing() }

        do {
            try await convertMedia(
                file: file,
                sourceFormat: sourceFormat,
                targetFormat: targetFormat,
                outputURL: outputURL,
                appState: appState,
                preset: preset,
                options: options,
                deleteOriginal: deleteOriginal
            )
        } catch is CancellationError {
            log.info("[MediaConvert] cancelled before output was installed")
        } catch {
            handleMediaConversionError(error)
        }
    }

    private func resolveSourceFormat(for file: CustomFile) -> MediaFormat? {
        let fileExtension = file.urlValue.pathExtension.lowercased()
        guard let sourceFormat = MediaFormat.from(extension: fileExtension) else {
            showUnknownSourceFormatError(fileExtension)
            return nil
        }

        return sourceFormat
    }

    private func showUnknownSourceFormatError(_ fileExtension: String) {
        InAppNoticeCenter.shared.showError(
            title: "Convert Failed",
            message: "Unknown source format: .\(fileExtension)",
            scope: .mediaConvert
        )
    }

    private func logMediaConversionStart(
        file: CustomFile,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat
    ) {
        log.info(
            "[MediaConvert] starting \(sourceFormat.rawValue)→\(targetFormat.rawValue) " +
            "file='\(file.nameStr)'"
        )
    }

    private func finishMediaConversionProcessing() {
        isProcessing = false
    }

    private func convertMedia(
        file: CustomFile,
        sourceFormat: MediaFormat,
        targetFormat: MediaFormat,
        outputURL: URL,
        appState: AppState,
        preset: MediaConversionPreset?,
        options: MediaConversionOptions,
        deleteOriginal: Bool
    ) async throws {
        let mediaConversionService: MediaConversionService = .shared

        let convertedURL = try await mediaConversionService.convert(
            source: file.urlValue,
            target: outputURL,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
            preset: preset,
            options: options,
            onCancel: { [weak self] in
                self?.cancelMediaConversion()
            }
        )

        if deleteOriginal {
            _ = try await FileRecycleService.recycle(file.urlValue)
            log.info("[MediaConvert] moved original to Trash '\(file.nameStr)'")
        }

        refreshPanels(appState: appState)
        log.info("[MediaConvert] done → '\(convertedURL.lastPathComponent)'")
    }

    private func handleMediaConversionError(_ error: Error) {
        log.error("[MediaConvert] FAILED: \(error.localizedDescription)")
        let progressPanel: ProgressPanel = .shared
        guard !progressPanel.isCancelled else { return }

        InAppNoticeCenter.shared.showError(
            title: "Conversion Failed",
            message: error.localizedDescription,
            scope: .mediaConvert
        )
    }

    private func cancelMediaConversion() {
        let mediaConversionService: MediaConversionService = .shared
        mediaConversionService.cancelActiveConversion()
        log.info("[MediaConvert] user cancelled")
    }
}

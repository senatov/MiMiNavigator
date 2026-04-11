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
        appState: AppState
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
                appState: appState
            )
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
        activeDialog = .error(
            title: "Convert Failed",
            message: "Unknown source format: .\(fileExtension)"
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
        appState: AppState
    ) async throws {
        let mediaConversionService: MediaConversionService = .shared

        try await mediaConversionService.convert(
            source: file.urlValue,
            target: outputURL,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
            onCancel: { [weak self] in
                self?.cancelMediaConversion()
            }
        )

        refreshPanels(appState: appState)
        log.info("[MediaConvert] done → '\(outputURL.lastPathComponent)'")
    }

    private func handleMediaConversionError(_ error: Error) {
        log.error("[MediaConvert] FAILED: \(error.localizedDescription)")
        let progressPanel: ProgressPanel = .shared
        guard !progressPanel.isCancelled else { return }

        activeDialog = .error(
            title: "Conversion Failed",
            message: error.localizedDescription
        )
    }

    private func cancelMediaConversion() {
        let mediaConversionService: MediaConversionService = .shared
        mediaConversionService.cancelActiveConversion()
        log.info("[MediaConvert] user cancelled")
    }
}

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
        let ext = file.urlValue.pathExtension.lowercased()
        guard let sourceFormat = MediaFormat.from(extension: ext) else {
            activeDialog = .error(
                title: "Convert Failed",
                message: "Unknown source format: .\(ext)")
            return
        }

        log.info("[MediaConvert] starting \(sourceFormat.rawValue)→\(targetFormat.rawValue) file='\(file.nameStr)'")
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await MediaConversionService.shared.convert(
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
        } catch {
            log.error("[MediaConvert] FAILED: \(error.localizedDescription)")
            if !ProgressPanel.shared.isCancelled {
                activeDialog = .error(
                    title: "Conversion Failed",
                    message: error.localizedDescription)
            }
        }
    }

    private func cancelMediaConversion() {
        MediaConversionService.shared.cancelActiveConversion()
        log.info("[MediaConvert] user cancelled")
    }
}

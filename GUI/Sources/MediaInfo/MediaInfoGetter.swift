import AppKit
//
//  MediaInfoGetter.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import Foundation
import QuartzCore

final class MediaInfoGetter: @unchecked Sendable {

    func getMediaInfoToFile(url: URL, fast: Bool = false) {
        log.info("[MediaInfo] request file='\(url.path)'")

        Task { @MainActor in
            let progress = FileOpProgress(totalFiles: 1, totalBytes: 1)
            ProgressPanel.shared.show(archiveName: "Media Info", destinationPath: url.path)
            self.updateProgressPanel(text: "Processing…")

            Task.detached(priority: .userInitiated) { @Sendable [url, fast, progress] in
                let getter = MediaInfoGetter()
                await getter.runProcess(url: url, fast: fast, progress: progress)
            }
        }
    }

    // MARK: - Core

    private func runProcess(url: URL, fast: Bool, progress: FileOpProgress) async {
        log.debug("[MediaInfo] start processing '\(url.path)'")

        // Simulated media info extraction (replace later with real native logic)
        let fileName = url.lastPathComponent

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let sizeMB = Double(size) / (1024 * 1024)

            let info = """
            File: \(fileName)
            Size: \(String(format: "%.2f", sizeMB)) MB
            Path: \(url.path)
            """

            await MainActor.run {
                ProgressPanel.shared.show(archiveName: "Media Info", destinationPath: url.path)
                ProgressPanel.shared.update(text: info)

                // Auto-hide after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    ProgressPanel.shared.hide()
                }
            }

            log.info("[MediaInfo] info displayed for '\(fileName)'")

        } catch {
            log.error("[MediaInfo] failed to read file attributes: \(error)")
            await MainActor.run {
                ProgressPanel.shared.show(archiveName: "Media Info", destinationPath: url.path)
                ProgressPanel.shared.update(text: "Failed to read file info")
                ProgressPanel.shared.hide()
            }
        }
    }

    @MainActor
    private static func updateProgressPanelStatic(text: String) {
        ProgressPanel.shared.update(text: text)
    }

    // MARK: - UI Update

    @MainActor
    private func updateProgressPanel(text: String) {
        let now = CACurrentMediaTime()

        // Avoid redundant updates
        if lastProgressText == text { return }

        // Throttle updates (max ~10 fps)
        if now - lastUpdateTime < 0.1 { return }

        lastProgressText = text
        lastUpdateTime = now

        ProgressPanel.shared.update(text: text)
    }

    private var lastProgressText: String = ""
    private var lastUpdateTime: CFTimeInterval = 0
}

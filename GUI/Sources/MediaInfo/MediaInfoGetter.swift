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
import ImageIO
import AVFoundation

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

            var lines: [String] = []

            lines.append("File: \(fileName)")
            lines.append("Size: \(String(format: "%.2f", sizeMB)) MB")
            lines.append("Path: \(url.path)")

            // MARK: - Image metadata
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let metadata = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] {

                if let w = metadata[kCGImagePropertyPixelWidth as String],
                   let h = metadata[kCGImagePropertyPixelHeight as String] {
                    lines.append("Resolution: \(w)x\(h)")
                }

                if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
                   let date = exif[kCGImagePropertyExifDateTimeOriginal as String] {
                    lines.append("Date: \(date)")
                }

                if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    if let lat = gps[kCGImagePropertyGPSLatitude as String],
                       let lon = gps[kCGImagePropertyGPSLongitude as String] {
                        lines.append("GPS: \(lat), \(lon)")
                    }
                }
            }

            // MARK: - Video / Audio metadata
            let asset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)

            if duration.isFinite && duration > 0 {
                lines.append("Duration: \(String(format: "%.2f", duration)) sec")
            }

            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                let width = abs(size.width)
                let height = abs(size.height)
                lines.append("Video: \(Int(width))x\(Int(height))")
            }

            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                let sampleRate = audioTrack.naturalTimeScale
                lines.append("Audio sample rate: \(sampleRate)")
            }

            let info = lines.joined(separator: "\n")

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

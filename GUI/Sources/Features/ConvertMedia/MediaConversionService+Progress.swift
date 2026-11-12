// MediaConversionService+Progress.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import ExternalToolsKit
import Foundation

// MARK: - FFmpeg progress
@MainActor
extension MediaConversionService {
    // MARK: - Probe source duration
    func probeDuration(of source: URL, panel: ProgressPanel) async -> Double? {
        guard let path = ExternalToolCatalog.ffprobe.resolvedPath else { return nil }
        do {
            let output = try await runProcess(
                executablePath: path,
                arguments: ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", source.path],
                panel: panel
            )
            guard let duration = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)), duration.isFinite, duration > 0 else { return nil }
            return duration
        } catch {
            log.warning("[MediaConvert] duration probe failed for \(source.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Update numeric progress
    func updateFFmpegProgress(from output: String, duration: Double, panel: ProgressPanel) {
        guard let fraction = Self.ffmpegProgressFraction(from: output, duration: duration) else { return }
        panel.updateProgress(min(fraction, 0.99))
    }

    // MARK: - Parse the most recent complete FFmpeg timestamp
    nonisolated static func ffmpegProgressFraction(from output: String, duration: Double) -> Double? {
        guard duration > 0, duration.isFinite else { return nil }
        let lines = output.split(separator: "\n")
        guard let line = lines.last(where: { $0.hasPrefix("out_time=") }) else { return nil }
        let fields = line.dropFirst("out_time=".count).split(separator: ":")
        guard fields.count == 3,
              let hours = Double(fields[0]), let minutes = Double(fields[1]), let seconds = Double(fields[2]) else { return nil }
        let elapsed = hours * 3600 + minutes * 60 + seconds
        guard elapsed.isFinite, elapsed >= 0 else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }
}

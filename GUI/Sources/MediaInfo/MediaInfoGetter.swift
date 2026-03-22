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
            self.updateProgressPanel(text: "Processing…")

            Task.detached(priority: .userInitiated) { @Sendable [weak self, url, fast, progress] in
                guard let self else {
                    log.debug("[MediaInfo] task cancelled — self deallocated")
                    return
                }
                await self.runProcess(url: url, fast: fast, progress: progress)
            }
        }
    }

    // MARK: - Core

    private func runProcess(url: URL, fast: Bool, progress: FileOpProgress) async {
        // progress.completedUnitCount = 5
        log.debug("[MediaInfo] start processing '\(url.path)'")

        guard let resourcePath = Bundle.main.resourcePath else {
            log.error("[MediaInfo] resource path not found")
            await MainActor.run {
                ProgressPanel.shared.hide()
            }
            return
        }
        let scriptURL = URL(fileURLWithPath: resourcePath).appendingPathComponent("Python/getFromMedia.py")
        let scriptPath = scriptURL.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

        var args = [scriptPath, url.path]
        if fast {
            args.append("--fast")
        }
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Live progress reading from Python stdout
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }

            // Parse progress lines from Python
            let lines = chunk.split(separator: "\n")
            for line in lines {
                if line.starts(with: "PROGRESS:") {
                    let payload = line.replacingOccurrences(of: "PROGRESS:", with: "").trimmingCharacters(in: .whitespaces)

                    let parts = payload.split(separator: ":", maxSplits: 1)
                    let percent = parts.first.map(String.init) ?? ""
                    let message = parts.count > 1 ? String(parts[1]) : ""

                    let text = message.isEmpty
                        ? "Processing… \(percent)%"
                        : "\(message.capitalized) (\(percent)%)"

                    Task { @MainActor in
                        MediaInfoGetter.updateProgressPanelStatic(text: text)
                    }
                }
            }
        }

        log.debug("[MediaInfo] launching python script='\(scriptPath)'")

        let pipeRef = pipe
        process.terminationHandler = { [weak self] proc in
            guard let self else { return }

            // Disable readabilityHandler before reading full data
            pipeRef.fileHandleForReading.readabilityHandler = nil
            let data = pipeRef.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            log.debug("[MediaInfo] process finished (code=\(proc.terminationStatus)), bytes=\(data.count)")

            Task { @MainActor in
                // progress.completedUnitCount = 100
                ProgressPanel.shared.hide()

                if output.contains("[ERROR]") {
                    log.error("[MediaInfo] script error detected")
                    self.writeOutput(output)
                    self.openResultFile()
                    return
                }

                self.writeOutput(output)
                self.openResultFile()
            }
        }

        do {
            try process.run()
        } catch {
            log.error("[MediaInfo] failed to start python: \(error)")
            await MainActor.run {
                ProgressPanel.shared.hide()
            }
            return
        }

        // progress.completedUnitCount = 20

        // Timeout watchdog (30s)
        Task.detached { @Sendable [weak process] in
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            if let process, process.isRunning {
                log.error("[MediaInfo] process timeout — terminating")
                process.terminate()
                await MainActor.run {
                    ProgressPanel.shared.hide()
                }
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

    // MARK: - IO

    private func writeOutput(_ output: String) {
        let outFile = "/tmp/osmic5673.asc"

        do {
            try output.write(toFile: outFile, atomically: true, encoding: .utf8)
            log.info("[MediaInfo] written to \(outFile)")
        } catch {
            log.error("[MediaInfo] write failed: \(error)")
        }
    }

    private func openResultFile() {
        let outFile = "/tmp/osmic5673.asc"
        let url = URL(fileURLWithPath: outFile)
        NSWorkspace.shared.open(url)
    }
}

// FileOpProgress.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Observable progress state for file operations — drives the progress panel

import Foundation

// MARK: - File Operation Progress
/// Thread-safe progress tracker for copy/move/delete operations.
/// UI reads properties from MainActor; workers call `add(bytes:)` from any context.
@MainActor
@Observable
final class FileOpProgress {

    // MARK: - Configured at init
    let totalFiles: Int
    let totalBytes: Int64
    let operationType: FileOpType
    let destinationURL: URL?

    // MARK: - Live state
    var processedFiles: Int = 0
    var skippedFiles: Int = 0
    var processedBytes: Int64 = 0
    var currentFileName: String = ""
    var isCancelled: Bool = false
    var isCompleted: Bool = false
    var usesProgressPanel: Bool = false
    var errors: [FileOpErrorInfo] = []

    // MARK: - Timing
    let startTime: Date = Date()
    var endTime: Date?

    // MARK: - Computed

    var fraction: Double {
        guard totalBytes > 0 else {
            guard totalFiles > 0 else { return 0 }
            return Double(processedFiles) / Double(totalFiles)
        }
        return Double(processedBytes) / Double(totalBytes)
    }

    var statusText: String {
        if isCancelled { return "Cancelled" }
        if isCompleted { return completionSummary }
        return "\(operationType.title) \(processedFiles + 1) / \(totalFiles)"
    }

    /// Detailed summary for completed operations
    var completionSummary: String {
        let ok = processedFiles - errors.count
        var parts: [String] = []
        if ok > 0 { parts.append("\(ok) \(operationType.pastTense)") }
        if skippedFiles > 0 { parts.append("\(skippedFiles) skipped") }
        if errors.count > 0 { parts.append("\(errors.count) failed") }
        return parts.isEmpty ? "Nothing to do" : parts.joined(separator: ", ")
    }

    var bytesText: String {
        guard totalBytes > 0 else { return "\(processedFiles) / \(totalFiles)" }
        let done = ByteCountFormatter.string(fromByteCount: processedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(done) / \(total)"
    }

    var elapsed: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var estimatedRemaining: TimeInterval? {
        guard processedBytes > 0, !isCompleted else { return nil }
        let rate = elapsed / Double(processedBytes)
        return Double(totalBytes - processedBytes) * rate
    }

    var showsProgressBar: Bool {
        totalFiles > 1 || totalBytes >= 8 * 1024 * 1024
    }

    // MARK: - Init

    init(totalFiles: Int, totalBytes: Int64, type: FileOpType = .copy, destination: URL? = nil) {
        self.totalFiles = totalFiles
        self.totalBytes = totalBytes
        self.operationType = type
        self.destinationURL = destination
    }

    // MARK: - Updates (call from workers via MainActor hop)

    func setCurrentFile(_ name: String) {
        currentFileName = name
        guard usesProgressPanel else { return }
        ProgressPanel.shared.updateStatus("\(operationType.title) \(processedFiles + 1) / \(totalFiles): \(name)")
        updateProgressDisplay()
    }

    func add(bytes: Int64) {
        processedBytes += bytes
        guard usesProgressPanel else { return }
        updateProgressDisplay()
    }

    func fileCompleted(name: String, success: Bool, error: String? = nil) {
        processedFiles += 1
        if !success, let err = error {
            errors.append(FileOpErrorInfo(fileName: name, error: err))
            guard usesProgressPanel else { return }
            ProgressPanel.shared.appendLog("Failed: \(name) - \(err)")
        } else {
            guard usesProgressPanel else { return }
            ProgressPanel.shared.appendLog("\(operationType.pastTense.capitalized): \(name)")
        }
        ProgressPanel.shared.updateStatus(statusText)
        updateProgressDisplay()
    }

    func fileSkipped(name: String) {
        skippedFiles += 1
        guard usesProgressPanel else { return }
        ProgressPanel.shared.appendLog("Skipped: \(name)")
        ProgressPanel.shared.updateStatus(statusText)
        updateProgressDisplay()
    }

    func cancel() {
        isCancelled = true
        endTime = Date()
        guard usesProgressPanel else { return }
        ProgressPanel.shared.appendLog("Cancelled by user")
        ProgressPanel.shared.finish(success: false, message: "Cancelled")
        log.info("[FileOpProgress] cancelled at \(processedFiles)/\(totalFiles)")
    }

    func complete() {
        guard !isCancelled else { return }
        isCompleted = true
        endTime = Date()
        if usesProgressPanel {
            ProgressPanel.shared.finish(success: errors.isEmpty, message: completionSummary)
        }
        log.info("[FileOpProgress] done: \(processedFiles) ok, \(skippedFiles) skipped, \(errors.count) errs, \(String(format: "%.1f", elapsed))s")
    }

    func updateStatusOnly(_ text: String) {
        guard usesProgressPanel else { return }
        ProgressPanel.shared.updateStatus(text)
    }

    private func updateProgressDisplay() {
        guard usesProgressPanel else { return }
        if showsProgressBar {
            ProgressPanel.shared.updateProgress(fraction)
        } else {
            ProgressPanel.shared.hideProgress()
        }
    }
}

// MARK: - Error Info
struct FileOpErrorInfo: Identifiable, Sendable {
    let id = UUID()
    let fileName: String
    let error: String
}

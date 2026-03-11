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
    var processedBytes: Int64 = 0
    var currentFileName: String = ""
    var isCancelled: Bool = false
    var isCompleted: Bool = false
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
        if isCompleted {
            let ok = processedFiles - errors.count
            if errors.isEmpty {
                return "\(operationType.pastTense) \(ok) item(s)"
            }
            return "\(ok) succeeded, \(errors.count) failed"
        }
        return "\(operationType.title) \(processedFiles + 1) / \(totalFiles)"
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
    }

    func add(bytes: Int64) {
        processedBytes += bytes
    }

    func fileCompleted(name: String, success: Bool, error: String? = nil) {
        processedFiles += 1
        if !success, let err = error {
            errors.append(FileOpErrorInfo(fileName: name, error: err))
        }
    }

    func cancel() {
        isCancelled = true
        endTime = Date()
        log.info("[FileOpProgress] cancelled at \(processedFiles)/\(totalFiles)")
    }

    func complete() {
        isCompleted = true
        endTime = Date()
        log.info("[FileOpProgress] done: \(processedFiles) files, \(errors.count) errs, \(String(format: "%.1f", elapsed))s")
    }
}

// MARK: - Error Info
struct FileOpErrorInfo: Identifiable, Sendable {
    let id = UUID()
    let fileName: String
    let error: String
}

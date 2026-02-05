// BatchOperationState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: State tracking for batch file operations with progress

import Foundation

// MARK: - Batch Operation Type
enum BatchOperationType: String, Sendable {
    case copy = "Copying"
    case move = "Moving"
    case delete = "Deleting"
    case pack = "Packing"
    
    var localizedTitle: String {
        switch self {
        case .copy: return L10n.BatchOperation.copying
        case .move: return L10n.BatchOperation.moving
        case .delete: return L10n.BatchOperation.deleting
        case .pack: return L10n.BatchOperation.packing
        }
    }
    
    var pastTense: String {
        switch self {
        case .copy: return L10n.BatchOperation.copied
        case .move: return L10n.BatchOperation.moved
        case .delete: return L10n.BatchOperation.deleted
        case .pack: return L10n.BatchOperation.packed
        }
    }
}

// MARK: - Operation Error Info
struct OperationErrorInfo: Identifiable, Sendable {
    let id = UUID()
    let fileName: String
    let error: String
}

// MARK: - Batch Operation State
/// Tracks progress and state of a batch file operation
@MainActor
@Observable
final class BatchOperationState {
    
    // MARK: - Operation Info
    let operationType: BatchOperationType
    let sourcePanel: PanelSide
    let destinationURL: URL?
    let totalFiles: Int
    
    // MARK: - Progress State
    var processedFiles: Int = 0
    var currentFileName: String = ""
    var currentFileSize: Int64 = 0
    var processedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    
    // MARK: - Status
    var isCancelled: Bool = false
    var isCompleted: Bool = false
    var errors: [OperationErrorInfo] = []
    
    // MARK: - Timing
    let startTime: Date
    var endTime: Date?
    
    // MARK: - Computed Properties
    
    var progressFraction: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }
    
    var bytesProgressFraction: Double {
        guard totalBytes > 0 else { return progressFraction }
        return Double(processedBytes) / Double(totalBytes)
    }
    
    var elapsedTime: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var estimatedTimeRemaining: TimeInterval? {
        guard processedFiles > 0, !isCompleted else { return nil }
        let rate = elapsedTime / Double(processedFiles)
        let remaining = Double(totalFiles - processedFiles) * rate
        return remaining
    }
    
    var statusText: String {
        if isCancelled {
            return L10n.BatchOperation.cancelled
        }
        if isCompleted {
            let successCount = processedFiles - errors.count
            if errors.isEmpty {
                return L10n.BatchOperation.completedSuccess(successCount, operationType.pastTense)
            } else {
                return L10n.BatchOperation.completedWithErrors(successCount, errors.count)
            }
        }
        return "\(operationType.localizedTitle) \(processedFiles + 1) / \(totalFiles)"
    }
    
    var progressText: String {
        if totalBytes > 0 {
            let processed = ByteCountFormatter.string(fromByteCount: processedBytes, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(processed) / \(total)"
        }
        return "\(processedFiles) / \(totalFiles)"
    }
    
    // MARK: - Initialization
    
    init(
        operationType: BatchOperationType,
        sourcePanel: PanelSide,
        destinationURL: URL?,
        files: [CustomFile]
    ) {
        self.operationType = operationType
        self.sourcePanel = sourcePanel
        self.destinationURL = destinationURL
        self.totalFiles = files.count
        self.totalBytes = files.reduce(0) { $0 + $1.sizeInBytes }
        self.startTime = Date()
        
        log.debug("[BatchOperationState] init: \(operationType.rawValue) \(files.count) files")
    }
    
    // MARK: - Progress Updates
    
    func updateProgress(fileName: String, fileSize: Int64) {
        currentFileName = fileName
        currentFileSize = fileSize
    }
    
    func fileCompleted(success: Bool, error: String? = nil) {
        processedFiles += 1
        processedBytes += currentFileSize
        
        if !success, let errorMsg = error {
            errors.append(OperationErrorInfo(fileName: currentFileName, error: errorMsg))
        }
        
        log.debug("[BatchOperationState] completed \(processedFiles)/\(totalFiles): \(currentFileName)")
    }
    
    func cancel() {
        isCancelled = true
        endTime = Date()
        log.info("[BatchOperationState] cancelled at \(processedFiles)/\(totalFiles)")
    }
    
    func complete() {
        isCompleted = true
        endTime = Date()
        log.info("[BatchOperationState] completed: \(processedFiles) files, \(errors.count) errors, \(String(format: "%.1f", elapsedTime))s")
    }
}

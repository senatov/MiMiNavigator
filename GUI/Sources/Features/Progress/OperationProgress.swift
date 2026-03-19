// OperationProgress.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Progress tracking model for lengthy file/archive operations.

import Foundation

// MARK: - Operation Type

/// Type of file operation being performed
enum FileOperationType: String, Sendable {
    case copy       = "Copy"
    case move       = "Move"
    case delete     = "Delete"
    case archive    = "Archive"
    case extract    = "Extract"
    case upload     = "Upload"
    case download   = "Download"
    
    var icon: String {
        switch self {
        case .copy:     return "doc.on.doc"
        case .move:     return "arrow.right.doc.on.clipboard"
        case .delete:   return "trash"
        case .archive:  return "archivebox"
        case .extract:  return "archivebox.fill"
        case .upload:   return "arrow.up.circle"
        case .download: return "arrow.down.circle"
        }
    }
    
    var verb: String {
        switch self {
        case .copy:     return "Copying"
        case .move:     return "Moving"
        case .delete:   return "Deleting"
        case .archive:  return "Archiving"
        case .extract:  return "Extracting"
        case .upload:   return "Uploading"
        case .download: return "Downloading"
        }
    }
}

// MARK: - Operation State

enum OperationState: Sendable, Equatable {
    case pending
    case estimating
    case running
    case paused
    case cancelling
    case completed
    case failed(String)  // Error message instead of Error for Equatable
    
    var isActive: Bool {
        switch self {
        case .pending, .estimating, .running, .paused, .cancelling: return true
        case .completed, .failed: return false
        }
    }
    
    var isCancelling: Bool {
        if case .cancelling = self { return true }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

// MARK: - Operation Estimate

/// Pre-operation estimate — computed before starting
struct OperationEstimate: Sendable {
    let totalFiles: Int
    let totalDirectories: Int
    let totalBytes: Int64
    let estimatedSeconds: TimeInterval
    
    /// Threshold: show progress panel if operation is "lengthy"
    var isLengthy: Bool {
        totalFiles > 50 || totalBytes > 50_000_000 || estimatedSeconds > 3
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var formattedTime: String {
        if estimatedSeconds < 60 {
            return "~\(Int(estimatedSeconds)) sec"
        } else if estimatedSeconds < 3600 {
            let min = Int(estimatedSeconds / 60)
            let sec = Int(estimatedSeconds.truncatingRemainder(dividingBy: 60))
            return "~\(min) min \(sec) sec"
        } else {
            let hr = Int(estimatedSeconds / 3600)
            let min = Int((estimatedSeconds / 60).truncatingRemainder(dividingBy: 60))
            return "~\(hr)h \(min)m"
        }
    }
}

// MARK: - Operation Progress

/// Live progress data — updated during operation
@MainActor
@Observable
final class OperationProgress {
    
    // MARK: - Static info
    let id: UUID
    let operationType: FileOperationType
    let sourceURLs: [URL]
    let destinationURL: URL?
    let startTime: Date
    
    // MARK: - Estimate (computed before start)
    var estimate: OperationEstimate?
    
    // MARK: - Live progress
    private(set) var state: OperationState = .pending
    private(set) var processedFiles: Int = 0
    private(set) var processedBytes: Int64 = 0
    private(set) var currentFile: String = ""
    private(set) var errors: [OperationError] = []
    
    // MARK: - Speed calculation
    private var bytesHistory: [(Date, Int64)] = []
    private(set) var speedBytesPerSec: Double = 0
    
    // MARK: - Init
    init(type: FileOperationType, sources: [URL], destination: URL? = nil) {
        self.id = UUID()
        self.operationType = type
        self.sourceURLs = sources
        self.destinationURL = destination
        self.startTime = Date()
    }
    
    // MARK: - Computed properties
    
    var progress: Double {
        guard let est = estimate, est.totalBytes > 0 else { return 0 }
        return min(1.0, Double(processedBytes) / Double(est.totalBytes))
    }
    
    var percentComplete: Int {
        Int(progress * 100)
    }
    
    var remainingTime: TimeInterval? {
        guard speedBytesPerSec > 0, let est = estimate else { return nil }
        let remaining = est.totalBytes - processedBytes
        return TimeInterval(remaining) / speedBytesPerSec
    }
    
    var formattedRemainingTime: String {
        guard let secs = remainingTime else { return "calculating…" }
        if secs < 60 { return "~\(Int(secs)) sec" }
        let min = Int(secs / 60)
        let sec = Int(secs.truncatingRemainder(dividingBy: 60))
        return "~\(min) min \(sec) sec"
    }
    
    var formattedSpeed: String {
        let bps = Int64(speedBytesPerSec)
        return ByteCountFormatter.string(fromByteCount: bps, countStyle: .file) + "/s"
    }
    
    var formattedProcessed: String {
        ByteCountFormatter.string(fromByteCount: processedBytes, countStyle: .file)
    }
    
    // MARK: - Update methods
    
    func updateState(_ newState: OperationState) {
        state = newState
    }
    
    func updateProgress(file: String, bytes: Int64) {
        currentFile = file
        processedFiles += 1
        processedBytes += bytes
        updateSpeed()
    }
    
    func addBytes(_ bytes: Int64) {
        processedBytes += bytes
        updateSpeed()
    }
    
    func addError(_ error: OperationError) {
        errors.append(error)
    }
    
    private func updateSpeed() {
        let now = Date()
        bytesHistory.append((now, processedBytes))
        // Keep last 5 seconds of history
        bytesHistory = bytesHistory.filter { now.timeIntervalSince($0.0) < 5 }
        
        if let oldest = bytesHistory.first, bytesHistory.count > 1 {
            let elapsed = now.timeIntervalSince(oldest.0)
            let bytesDelta = processedBytes - oldest.1
            if elapsed > 0.5 {
                speedBytesPerSec = Double(bytesDelta) / elapsed
            }
        }
    }
}

// MARK: - Operation Error

struct OperationError: Sendable {
    let url: URL
    let message: String
    let isRecoverable: Bool
}

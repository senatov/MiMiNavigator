// OperationCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinates file operations — estimates, shows progress panel if lengthy,
//   executes operation with progress tracking.

import AppKit
import Foundation

// MARK: - Operation Coordinator

@MainActor
final class OperationCoordinator {
    
    static let shared = OperationCoordinator()
    private init() {}
    
    private var activeOperations: [UUID: OperationProgress] = [:]
    private var progressPanel: OperationProgressPanel?
    
    // MARK: - Public API
    
    /// Start a copy operation with automatic progress tracking
    func copy(
        sources: [URL],
        destination: URL,
        isRemote: Bool = false
    ) async throws {
        try await executeOperation(
            type: .copy,
            sources: sources,
            destination: destination,
            isRemote: isRemote
        )
    }
    
    /// Start a move operation
    func move(
        sources: [URL],
        destination: URL,
        isRemote: Bool = false
    ) async throws {
        try await executeOperation(
            type: .move,
            sources: sources,
            destination: destination,
            isRemote: isRemote
        )
    }
    
    /// Start a delete operation
    func delete(sources: [URL]) async throws {
        try await executeOperation(
            type: .delete,
            sources: sources,
            destination: nil,
            isRemote: false
        )
    }
    
    // MARK: - Core Execution
    
    private func executeOperation(
        type: FileOperationType,
        sources: [URL],
        destination: URL?,
        isRemote: Bool
    ) async throws {
        
        // 1. Create progress tracker
        let progress = OperationProgress(type: type, sources: sources, destination: destination)
        activeOperations[progress.id] = progress
        
        defer {
            activeOperations.removeValue(forKey: progress.id)
        }
        
        // 2. Estimate operation
        progress.updateState(.estimating)
        let estimate = await OperationEstimator.shared.estimate(
            urls: sources,
            operation: type,
            destination: destination,
            isRemote: isRemote
        )
        progress.estimate = estimate
        
        log.info("[OpCoord] Estimate: \(estimate.totalFiles) files, \(estimate.formattedSize), \(estimate.formattedTime)")
        
        // 3. Show confirmation if lengthy
        if estimate.isLengthy {
            let confirmed = await showConfirmation(for: progress, estimate: estimate)
            if !confirmed {
                log.info("[OpCoord] User cancelled before start")
                return
            }
            
            // Show progress panel
            progressPanel = OperationProgressPanel()
            progressPanel?.onPause = { [weak self] in
                Task { await self?.togglePause(progress) }
            }
            progressPanel?.onCancel = { [weak self] in
                Task { await self?.cancelOperation(progress) }
            }
            progressPanel?.show(for: progress)
        }
        
        // 4. Execute operation
        progress.updateState(.running)
        
        do {
            switch type {
            case .copy:
                try await performCopy(sources: sources, destination: destination!, progress: progress)
            case .move:
                try await performMove(sources: sources, destination: destination!, progress: progress)
            case .delete:
                try await performDelete(sources: sources, progress: progress)
            default:
                break
            }
            
            progress.updateState(.completed)
            log.info("[OpCoord] Completed: \(progress.processedFiles) files")
            
        } catch {
            progress.updateState(.failed(error.localizedDescription))
            throw error
        }
        
        // 5. Hide panel after short delay
        if estimate.isLengthy {
            try? await Task.sleep(for: .milliseconds(500))
            progressPanel?.hide()
        }
    }
    
    // MARK: - Confirmation Dialog
    
    private func showConfirmation(for op: OperationProgress, estimate: OperationEstimate) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "\(op.operationType.rawValue) \(estimate.totalFiles) files?"
            alert.informativeText = """
                Total size: \(estimate.formattedSize)
                Estimated time: \(estimate.formattedTime)
                
                This operation may take a while.
                """
            alert.alertStyle = .informational
            alert.addButton(withTitle: op.operationType.rawValue)
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
    
    // MARK: - Pause / Cancel
    
    private func togglePause(_ progress: OperationProgress) async {
        switch progress.state {
        case .running:
            progress.updateState(.paused)
            log.info("[OpCoord] Paused")
        case .paused:
            progress.updateState(.running)
            log.info("[OpCoord] Resumed")
        default:
            break
        }
    }
    
    private func cancelOperation(_ progress: OperationProgress) async {
        progress.updateState(.cancelling)
        log.info("[OpCoord] Cancelling...")
        // Actual cancellation handled by operation loop checking state
    }
    
    // MARK: - Perform Operations
    
    private func performCopy(sources: [URL], destination: URL, progress: OperationProgress) async throws {
        let fm = FileManager.default
        
        for source in sources {
            if progress.state == .cancelling { break }
            
            while progress.state == .paused {
                try await Task.sleep(for: .milliseconds(100))
            }
            
            let destURL = destination.appendingPathComponent(source.lastPathComponent)
            
            if source.isDirectory {
                try await copyDirectory(source: source, destination: destURL, progress: progress)
            } else {
                try fm.copyItem(at: source, to: destURL)
                let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                progress.updateProgress(file: source.lastPathComponent, bytes: size)
            }
        }
    }
    
    private func copyDirectory(source: URL, destination: URL, progress: OperationProgress) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        while let itemURL = enumerator.nextObject() as? URL {
            if progress.state == .cancelling { break }
            
            while progress.state == .paused {
                try await Task.sleep(for: .milliseconds(100))
            }
            
            let relativePath = itemURL.path.replacingOccurrences(of: source.path, with: "")
            let destItemURL = destination.appendingPathComponent(relativePath)
            
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            
            if values?.isDirectory == true {
                try fm.createDirectory(at: destItemURL, withIntermediateDirectories: true)
            } else {
                try fm.copyItem(at: itemURL, to: destItemURL)
                let size = Int64(values?.fileSize ?? 0)
                progress.updateProgress(file: itemURL.lastPathComponent, bytes: size)
            }
        }
    }
    
    private func performMove(sources: [URL], destination: URL, progress: OperationProgress) async throws {
        let fm = FileManager.default
        
        for source in sources {
            if progress.state == .cancelling { break }
            
            while progress.state == .paused {
                try await Task.sleep(for: .milliseconds(100))
            }
            
            let destURL = destination.appendingPathComponent(source.lastPathComponent)
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            
            try fm.moveItem(at: source, to: destURL)
            progress.updateProgress(file: source.lastPathComponent, bytes: size)
        }
    }
    
    private func performDelete(sources: [URL], progress: OperationProgress) async throws {
        let fm = FileManager.default
        
        for source in sources {
            if progress.state == .cancelling { break }
            
            while progress.state == .paused {
                try await Task.sleep(for: .milliseconds(100))
            }
            
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            try fm.removeItem(at: source)
            progress.updateProgress(file: source.lastPathComponent, bytes: size)
        }
    }
}

// MARK: - URL Extension

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}

// BatchOperationManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages batch file operations with progress tracking and cancellation

import Foundation

// MARK: - Batch Operation Manager
/// Coordinates batch file operations (copy, move, delete, pack) with progress and cancellation
@MainActor
@Observable
final class BatchOperationManager {
    
    static let shared = BatchOperationManager()
    
    // MARK: - State
    var currentOperation: BatchOperationState?
    var showProgressDialog: Bool = false
    
    // MARK: - Dependencies
    private let fileManager = FileManager.default
    
    private init() {
        log.debug("[BatchOperationManager] initialized")
    }
    
    // MARK: - Copy Files
    
    func copyFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOperationManager] copy \(files.count) files to \(destination.path)")
        
        let state = BatchOperationState(
            operationType: .copy,
            sourcePanel: sourcePanel,
            destinationURL: destination,
            files: files
        )
        currentOperation = state
        showProgressDialog = true
        
        defer {
            state.complete()
            Task { @MainActor in
                await refreshPanelsAfterOperation(appState: appState, sourcePanel: sourcePanel)
            }
        }
        
        for file in files {
            guard !state.isCancelled else { break }
            
            state.updateProgress(fileName: file.nameStr, fileSize: file.sizeInBytes)
            
            do {
                let targetURL = destination.appendingPathComponent(file.nameStr)
                let finalURL = try await copyFileWithConflictHandling(
                    source: file.urlValue,
                    target: targetURL,
                    state: state
                )
                
                if finalURL != nil {
                    state.fileCompleted(success: true)
                } else {
                    // Skipped
                    state.fileCompleted(success: true)
                }
            } catch {
                state.fileCompleted(success: false, error: error.localizedDescription)
            }
            
            // Small delay for UI responsiveness
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Clear marks on source panel after successful operation
        if state.errors.isEmpty && !state.isCancelled {
            appState.clearMarksAfterOperation(on: sourcePanel)
        }
    }
    
    // MARK: - Move Files
    
    func moveFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOperationManager] move \(files.count) files to \(destination.path)")
        
        let state = BatchOperationState(
            operationType: .move,
            sourcePanel: sourcePanel,
            destinationURL: destination,
            files: files
        )
        currentOperation = state
        showProgressDialog = true
        
        defer {
            state.complete()
            Task { @MainActor in
                await refreshPanelsAfterOperation(appState: appState, sourcePanel: sourcePanel)
            }
        }
        
        for file in files {
            guard !state.isCancelled else { break }
            
            state.updateProgress(fileName: file.nameStr, fileSize: file.sizeInBytes)
            
            do {
                let targetURL = destination.appendingPathComponent(file.nameStr)
                let finalURL = try await moveFileWithConflictHandling(
                    source: file.urlValue,
                    target: targetURL,
                    state: state
                )
                
                if finalURL != nil {
                    state.fileCompleted(success: true)
                } else {
                    state.fileCompleted(success: true) // Skipped
                }
            } catch {
                state.fileCompleted(success: false, error: error.localizedDescription)
            }
            
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        if state.errors.isEmpty && !state.isCancelled {
            appState.clearMarksAfterOperation(on: sourcePanel)
        }
    }
    
    // MARK: - Delete Files
    
    func deleteFiles(
        _ files: [CustomFile],
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOperationManager] delete \(files.count) files")
        
        let state = BatchOperationState(
            operationType: .delete,
            sourcePanel: sourcePanel,
            destinationURL: nil,
            files: files
        )
        currentOperation = state
        showProgressDialog = true
        
        defer {
            state.complete()
            Task { @MainActor in
                await refreshPanelsAfterOperation(appState: appState, sourcePanel: sourcePanel)
            }
        }
        
        for file in files {
            guard !state.isCancelled else { break }
            
            state.updateProgress(fileName: file.nameStr, fileSize: file.sizeInBytes)
            
            do {
                try fileManager.trashItem(at: file.urlValue, resultingItemURL: nil)
                state.fileCompleted(success: true)
            } catch {
                state.fileCompleted(success: false, error: error.localizedDescription)
            }
            
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        if state.errors.isEmpty && !state.isCancelled {
            appState.clearMarksAfterOperation(on: sourcePanel)
        }
    }
    
    // MARK: - Pack Files
    
    func packFiles(
        _ files: [CustomFile],
        to archiveURL: URL,
        format: ArchiveFormat,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOperationManager] pack \(files.count) files to \(archiveURL.path)")
        
        let state = BatchOperationState(
            operationType: .pack,
            sourcePanel: sourcePanel,
            destinationURL: archiveURL.deletingLastPathComponent(),
            files: files
        )
        currentOperation = state
        showProgressDialog = true
        
        defer {
            state.complete()
            Task { @MainActor in
                await refreshPanelsAfterOperation(appState: appState, sourcePanel: sourcePanel)
            }
        }
        
        // For packing, we process all files as one operation
        state.updateProgress(fileName: archiveURL.lastPathComponent, fileSize: state.totalBytes)
        
        do {
            try await ArchiveService.shared.createArchive(
                from: files.map(\.urlValue),
                to: archiveURL,
                format: format,
                progressHandler: { progress in
                    state.processedBytes = Int64(Double(state.totalBytes) * progress)
                }
            )
            state.processedFiles = files.count
            state.fileCompleted(success: true)
        } catch {
            state.fileCompleted(success: false, error: error.localizedDescription)
        }
        
        if state.errors.isEmpty && !state.isCancelled {
            appState.clearMarksAfterOperation(on: sourcePanel)
        }
    }
    
    // MARK: - Cancel Current Operation
    
    func cancelCurrentOperation() {
        currentOperation?.cancel()
        log.info("[BatchOperationManager] operation cancelled by user")
    }
    
    // MARK: - Dismiss Progress Dialog
    
    func dismissProgressDialog() {
        showProgressDialog = false
        currentOperation = nil
    }
    
    // MARK: - Private Helpers
    
    private func copyFileWithConflictHandling(
        source: URL,
        target: URL,
        state: BatchOperationState
    ) async throws -> URL? {
        var finalTarget = target
        
        if fileManager.fileExists(atPath: target.path) {
            // Generate unique name (keep both)
            finalTarget = generateUniqueName(for: target)
        }
        
        if source.hasDirectoryPath {
            try copyDirectoryRecursively(from: source, to: finalTarget, state: state)
        } else {
            try fileManager.copyItem(at: source, to: finalTarget)
        }
        
        return finalTarget
    }
    
    private func moveFileWithConflictHandling(
        source: URL,
        target: URL,
        state: BatchOperationState
    ) async throws -> URL? {
        var finalTarget = target
        
        if fileManager.fileExists(atPath: target.path) {
            finalTarget = generateUniqueName(for: target)
        }
        
        try fileManager.moveItem(at: source, to: finalTarget)
        return finalTarget
    }
    
    private func copyDirectoryRecursively(
        from source: URL,
        to destination: URL,
        state: BatchOperationState
    ) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        
        for item in contents {
            guard !state.isCancelled else { return }
            
            let itemDest = destination.appendingPathComponent(item.lastPathComponent)
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                try copyDirectoryRecursively(from: item, to: itemDest, state: state)
            } else {
                try fileManager.copyItem(at: item, to: itemDest)
            }
        }
    }
    
    private func generateUniqueName(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 2
        var candidate: URL
        
        repeat {
            let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: candidate.path) && counter < 1000
        
        return candidate
    }
    
    private func refreshPanelsAfterOperation(appState: AppState, sourcePanel: PanelSide) async {
        await appState.refreshLeftFiles()
        await appState.refreshRightFiles()
    }
}

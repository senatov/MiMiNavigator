// ContextMenuCoordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Active Dialog Type
enum ActiveDialog: Identifiable {
    case deleteConfirmation(files: [CustomFile])
    case rename(file: CustomFile)
    case pack(files: [CustomFile], destination: URL)
    case createLink(file: CustomFile, destination: URL)
    case properties(file: CustomFile)
    case fileConflict(conflict: FileConflictInfo, continuation: CheckedContinuation<ConflictResolution, Never>)
    case error(title: String, message: String)
    case success(title: String, message: String)
    
    var id: String {
        switch self {
        case .deleteConfirmation: return "delete"
        case .rename: return "rename"
        case .pack: return "pack"
        case .createLink: return "createLink"
        case .properties: return "properties"
        case .fileConflict: return "conflict"
        case .error: return "error"
        case .success: return "success"
        }
    }
}

// MARK: - Context Menu Coordinator
/// Coordinates context menu actions with dialogs and file operations
@MainActor
@Observable
final class ContextMenuCoordinator {
    
    static let shared = ContextMenuCoordinator()
    
    // MARK: - State
    var activeDialog: ActiveDialog?
    var isProcessing = false
    
    // Dependencies
    private let fileOps = FileOperationsService.shared
    private let clipboard = ClipboardManager.shared
    private let archiveService = ArchiveService.shared
    
    private init() {}
    
    // MARK: - File Actions Handler
    func handleFileAction(_ action: FileAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        switch action {
        case .open:
            openFile(file)
            
        case .cut:
            clipboard.cut(files: [file], from: panel)
            
        case .copy:
            clipboard.copy(files: [file], from: panel)
            
        case .paste:
            Task {
                await performPaste(to: panel, appState: appState)
            }
            
        case .delete:
            activeDialog = .deleteConfirmation(files: [file])
            
        case .rename:
            activeDialog = .rename(file: file)
            
        case .pack:
            // Archive goes to OPPOSITE panel by default
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            activeDialog = .pack(files: [file], destination: destination)
            
        case .createLink:
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            activeDialog = .createLink(file: file, destination: destination)
            
        case .properties:
            activeDialog = .properties(file: file)
            
        case .viewLister:
            openQuickLook(file)
        }
    }
    
    // MARK: - Directory Actions Handler
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        switch action {
        case .open:
            // Handled by double-click in FilePanelView
            break
            
        case .openInNewTab:
            // TODO: Implement tab support
            log.info("Open in new tab: \(file.pathStr)")
            
        case .openInFinder:
            openInFinder(file)
            
        case .openInTerminal:
            openInTerminal(file)
            
        case .viewLister:
            openQuickLook(file)
            
        case .cut:
            clipboard.cut(files: [file], from: panel)
            
        case .copy:
            clipboard.copy(files: [file], from: panel)
            
        case .paste:
            Task {
                await performPaste(to: panel, appState: appState)
            }
            
        case .delete:
            activeDialog = .deleteConfirmation(files: [file])
            
        case .rename:
            activeDialog = .rename(file: file)
            
        case .pack:
            // Archive goes to OPPOSITE panel by default
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            activeDialog = .pack(files: [file], destination: destination)
            
        case .createLink:
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            activeDialog = .createLink(file: file, destination: destination)
            
        case .properties:
            activeDialog = .properties(file: file)
        }
    }
    
    // MARK: - Perform Delete
    func performDelete(files: [CustomFile], appState: AppState) async {
        isProcessing = true
        defer { 
            isProcessing = false 
            activeDialog = nil
        }
        
        do {
            let urls = files.map { $0.urlValue }
            _ = try await fileOps.deleteFiles(urls)
            
            // Refresh panels
            refreshPanels(appState: appState)
            
            log.info("Deleted \(files.count) item(s)")
        } catch {
            activeDialog = .error(title: "Delete Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Perform Rename
    func performRename(file: CustomFile, newName: String, appState: AppState) async {
        isProcessing = true
        defer { 
            isProcessing = false 
            activeDialog = nil
        }
        
        do {
            _ = try await fileOps.renameFile(file.urlValue, to: newName)
            
            // Refresh panels
            refreshPanels(appState: appState)
            
            log.info("Renamed: \(file.nameStr) → \(newName)")
        } catch {
            activeDialog = .error(title: "Rename Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Perform Pack
    func performPack(files: [CustomFile], archiveName: String, format: ArchiveFormat, destination: URL, appState: AppState) async {
        isProcessing = true
        defer { 
            isProcessing = false 
            activeDialog = nil
        }
        
        do {
            let urls = files.map { $0.urlValue }
            let archiveURL = try await archiveService.createArchive(
                from: urls,
                to: destination,
                archiveName: archiveName,
                format: format
            )
            
            // Refresh panels
            refreshPanels(appState: appState)
            
            activeDialog = .success(
                title: "Archive Created",
                message: "Created: \(archiveURL.lastPathComponent)"
            )
        } catch {
            activeDialog = .error(title: "Pack Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Perform Create Link
    func performCreateLink(file: CustomFile, linkName: String, linkType: LinkType, destination: URL, appState: AppState) async {
        isProcessing = true
        defer { 
            isProcessing = false 
            activeDialog = nil
        }
        
        do {
            switch linkType {
            case .symbolic:
                _ = try await fileOps.createSymbolicLink(
                    to: file.urlValue,
                    at: destination,
                    linkName: linkName
                )
            case .alias:
                // Alias creation using bookmark data
                try await createFinderAlias(to: file.urlValue, at: destination, name: linkName)
            }
            
            // Refresh panels
            refreshPanels(appState: appState)
            
            log.info("Created link: \(linkName)")
        } catch {
            activeDialog = .error(title: "Create Link Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Create Finder Alias
    private func createFinderAlias(to source: URL, at destination: URL, name: String) async throws {
        let aliasURL = destination.appendingPathComponent(name)
        
        let data = try source.bookmarkData(
            options: .suitableForBookmarkFile,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(data, to: aliasURL)
        log.info("Created Finder alias: \(aliasURL.lastPathComponent)")
    }
    
    // MARK: - Paste from Clipboard
    func performPaste(to panel: PanelSide, appState: AppState) async {
        guard clipboard.hasContent else {
            log.warning("Clipboard is empty")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let destination = getDestinationPath(for: panel, appState: appState)
        
        // Use new paste method with conflict handling
        let result = await clipboard.paste(to: destination, coordinator: self)
        
        switch result {
        case .success(let urls):
            log.info("Pasted \(urls.count) item(s)")
            refreshPanels(appState: appState)
            
        case .failure(let error):
            if case FileOperationError.operationCancelled = error {
                // User cancelled, don't show error
                log.info("Paste operation cancelled by user")
            } else {
                activeDialog = .error(title: "Paste Failed", message: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Open file with default app
    private func openFile(_ file: CustomFile) {
        NSWorkspace.shared.open(file.urlValue)
    }
    
    // MARK: - Open Quick Look
    private func openQuickLook(_ file: CustomFile) {
        // Use QLPreviewPanel for Quick Look
        NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
    }
    
    // MARK: - Show in Finder
    private func openInFinder(_ file: CustomFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
    }
    
    // MARK: - Open in Terminal
    private func openInTerminal(_ file: CustomFile) {
        let path = file.isDirectory ? file.urlValue.path : file.urlValue.deletingLastPathComponent().path
        
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                log.error("Failed to open Terminal: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    private func getDestinationPath(for panel: PanelSide, appState: AppState) -> URL {
        let path = panel == .left ? appState.leftPath : appState.rightPath
        return URL(fileURLWithPath: path)
    }
    
    private func getOppositeDestinationPath(for panel: PanelSide, appState: AppState) -> URL {
        let path = panel == .left ? appState.rightPath : appState.leftPath
        return URL(fileURLWithPath: path)
    }
    
    private func refreshPanels(appState: AppState) {
        log.debug("ContextMenuCoordinator: refreshing both panels")
        // Trigger async refresh - scanner.refreshFiles updates displayedLeftFiles/displayedRightFiles
        Task { @MainActor in
            await appState.scanner.refreshFiles(currSide: .left)
            await appState.scanner.refreshFiles(currSide: .right)
            log.debug("ContextMenuCoordinator: refresh completed")
        }
    }
    
    // MARK: - Show Conflict Dialog
    func showConflictDialog(conflict: FileConflictInfo) async -> ConflictResolution {
        await withCheckedContinuation { continuation in
            activeDialog = .fileConflict(conflict: conflict, continuation: continuation)
        }
    }
    
    // MARK: - Resolve Conflict (called from UI)
    func resolveConflict(_ resolution: ConflictResolution) {
        if case .fileConflict(_, let continuation) = activeDialog {
            activeDialog = nil
            continuation.resume(returning: resolution)
        }
    }
    
    // MARK: - Dismiss Dialog
    func dismissDialog() {
        activeDialog = nil
    }
}

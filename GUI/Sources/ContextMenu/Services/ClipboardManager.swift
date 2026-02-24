// ClipboardManager.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import Foundation
import FileModelKit
import SwiftUI

// MARK: - Clipboard Operation Type
enum ClipboardOperation {
    case copy
    case cut
}

// MARK: - Clipboard Manager
/// Manages internal clipboard for Cut/Copy/Paste operations between panels
/// Similar to Total Commander behavior
@MainActor
@Observable
final class ClipboardManager {
    
    static let shared = ClipboardManager()
    
    // MARK: - State
    private(set) var files: [URL] = []
    private(set) var operation: ClipboardOperation?
    private(set) var sourcePanel: PanelSide?
    
    var hasContent: Bool { !files.isEmpty && operation != nil }
    var isCut: Bool { operation == .cut }
    var isCopy: Bool { operation == .copy }
    
    private init() {}
    
    // MARK: - Copy files to clipboard
    func copy(files: [CustomFile], from panel: PanelSide) {
        self.files = files.map { $0.urlValue }
        self.operation = .copy
        self.sourcePanel = panel
        log.info("Clipboard: Copied \(files.count) item(s) from \(String(describing: panel))")
    }
    
    // MARK: - Cut files to clipboard
    func cut(files: [CustomFile], from panel: PanelSide) {
        self.files = files.map { $0.urlValue }
        self.operation = .cut
        self.sourcePanel = panel
        log.info("Clipboard: Cut \(files.count) item(s) from \(String(describing: panel))")
    }
    
    // MARK: - Paste files to destination with conflict handling
    func paste(to destination: URL, coordinator: ContextMenuCoordinator) async -> Result<[URL], Error> {
        guard hasContent else {
            return .failure(FileOperationError.operationFailed("Clipboard is empty"))
        }
        
        let fileOps = FileOperationsService.shared
        var resultURLs: [URL] = []
        let applyToAll: ConflictResolution? = nil  // TODO: implement "Apply to all" checkbox
        var stopped = false
        
        for file in files {
            if stopped { break }
            
            // Check for conflict
            if let conflict = fileOps.checkConflict(source: file, destination: destination) {
                let resolution: ConflictResolution
                
                if let cached = applyToAll {
                    resolution = cached
                } else {
                    // Show conflict dialog and wait for user decision
                    resolution = await coordinator.showConflictDialog(conflict: conflict)
                    
                    // TODO: Add "Apply to all" checkbox to dialog
                    // For now, ask for each file
                }
                
                switch resolution {
                case .stop:
                    stopped = true
                    continue
                case .skip:
                    continue
                case .keepBoth, .replace:
                    do {
                        let resultURL: URL
                        switch operation {
                        case .copy:
                            resultURL = try await fileOps.copyFile(file, to: destination, resolution: resolution)
                        case .cut:
                            resultURL = try await fileOps.moveFile(file, to: destination, resolution: resolution)
                        case .none:
                            continue
                        }
                        resultURLs.append(resultURL)
                    } catch {
                        log.error("File operation failed: \(error.localizedDescription)")
                        // Continue with next file
                    }
                }
            } else {
                // No conflict, proceed normally
                do {
                    let resultURL: URL
                    switch operation {
                    case .copy:
                        resultURL = try await fileOps.copyFile(file, to: destination, resolution: .keepBoth)
                    case .cut:
                        resultURL = try await fileOps.moveFile(file, to: destination, resolution: .keepBoth)
                    case .none:
                        continue
                    }
                    resultURLs.append(resultURL)
                } catch {
                    log.error("File operation failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Clear clipboard after successful cut-paste
        if operation == .cut && !resultURLs.isEmpty {
            clear()
        }
        
        log.info("Clipboard: Pasted \(resultURLs.count) item(s) to \(destination.path)")
        return .success(resultURLs)
    }
    
    // MARK: - Legacy paste (auto keep-both)
    func paste(to destination: URL) async -> Result<[URL], Error> {
        guard hasContent else {
            return .failure(FileOperationError.operationFailed("Clipboard is empty"))
        }
        
        do {
            let result: [URL]
            
            switch operation {
            case .copy:
                result = try await FileOperationsService.shared.copyFiles(files, to: destination)
            case .cut:
                result = try await FileOperationsService.shared.moveFiles(files, to: destination)
                clear()
            case .none:
                return .failure(FileOperationError.operationFailed("No operation specified"))
            }
            
            log.info("Clipboard: Pasted \(result.count) item(s) to \(destination.path)")
            return .success(result)
            
        } catch {
            log.error("Clipboard paste failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Clear clipboard
    func clear() {
        files = []
        operation = nil
        sourcePanel = nil
        log.debug("Clipboard: Cleared")
    }
    
    // MARK: - Get summary for UI
    var summary: String {
        guard hasContent else { return "Clipboard empty" }
        
        let opName = isCut ? "Cut" : "Copied"
        let itemWord = files.count == 1 ? "item" : "items"
        return "\(opName) \(files.count) \(itemWord)"
    }
}

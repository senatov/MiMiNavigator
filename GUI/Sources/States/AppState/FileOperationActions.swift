// FileOperationActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Quick file operations (copy to opposite panel)

import AppKit
import FileModelKit
import Foundation

// MARK: - File Operation Actions
/// Quick file operations triggered by keyboard shortcuts
@MainActor
final class FileOperationActions {
    
    // MARK: - Dependencies
    private weak var appState: AppState?
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
        log.debug("[FileOperationActions] initialized")
    }
    
    // MARK: - Copy to Opposite Panel
    
    /// Copy selected file to the opposite panel
    func copyToOppositePanel() {
        guard let state = appState else {
            log.error("[FileOperationActions] appState is nil")
            return
        }
        
        log.debug("[FileOperationActions] copyToOppositePanel focus=\(state.focusedPanel)")
        
        let srcFile: CustomFile?
        let dstSide: PanelSide
        
        switch state.focusedPanel {
        case .left:
            srcFile = state.selectedLeftFile
            dstSide = .right
        case .right:
            srcFile = state.selectedRightFile
            dstSide = .left
        }
        
        guard let file = srcFile else {
            log.debug("[FileOperationActions] no file selected")
            return
        }
        
        guard let dstDirURL = state.pathURL(for: dstSide) else {
            log.error("[FileOperationActions] destination unavailable")
            return
        }
        
        let srcURL = file.urlValue
        let dstURL = dstDirURL.appendingPathComponent(srcURL.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: dstURL.path) {
                log.warning("[FileOperationActions] skip: file exists at \(dstURL.path)")
                return
            }
            
            try fileManager.copyItem(at: srcURL, to: dstURL)
            log.info("[FileOperationActions] copied \(srcURL.lastPathComponent) → \(dstURL.path)")
            
            // Refresh destination panel
            Task { @MainActor in
                if dstSide == .left {
                    await state.refreshLeftFiles()
                } else {
                    await state.refreshRightFiles()
                }
            }
        } catch {
            log.error("[FileOperationActions] copy failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Open Selected Item
    
    /// Open selected item with default app or show Get Info for directories
    func openSelectedItem() {
        guard let state = appState else { return }
        log.debug("[FileOperationActions] openSelectedItem focus=\(state.focusedPanel)")
        let panel = state.focusedPanel
        let file = panel == .left ? state.selectedLeftFile : state.selectedRightFile
        guard let file else {
            log.warning("[FileOperationActions] no file selected")
            return
        }
        // Delegate to same logic as double-click — consistent with Finder behaviour
        state.activateItem(file, on: panel)
    }
}

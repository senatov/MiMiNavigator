//
// FavoritesNavigationAdapter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//
// Adapter to connect FavoritesKit with MiMiNavigator's AppState

import FavoritesKit
import Foundation

// MARK: - Adapter connecting FavoritesKit to AppState
@MainActor
final class FavoritesNavigationAdapter: FavoritesNavigationDelegate {
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - FavoritesNavigationDelegate
    
    var focusedPanel: FavPanelSide {
        appState.focusedPanel == .left ? .left : .right
    }
    
    func setFocusedPanel(_ panel: FavPanelSide) {
        appState.focusedPanel = panel == .left ? .left : .right
    }
    
    func navigateToPath(_ path: String, panel: FavPanelSide) async {
        let targetPanel: PanelSide = panel == .left ? .left : .right
        
        log.info("\(#function) path=\(path) panel=\(panel)")
        
        // Update path
        appState.updatePath(path, for: targetPanel)
        
        // Update selectedDir for UI consistency
        let file = CustomFile(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
        appState.selectedDir.selectedFSEntity = file
        
        // Refresh files
        await appState.scanner.resetRefreshTimer(for: targetPanel)
        await appState.scanner.refreshFiles(currSide: targetPanel)
    }
    
    func navigateBack(panel: FavPanelSide) {
        log.info("\(#function) panel=\(panel)")
        
        let targetPanel: PanelSide = panel == .left ? .left : .right
        let history = appState.navigationHistory(for: targetPanel)
        
        guard let path = history.goBack() else {
            log.debug("\(#function) no history to go back to")
            return
        }
        
        log.debug("\(#function) goBack returned path=\(path)")
        
        Task {
            appState.isNavigatingFromHistory = true
            do {
                await navigateToPath(path, panel: panel)
            }
            appState.isNavigatingFromHistory = false
        }
    }
    
    func navigateForward(panel: FavPanelSide) {
        log.info("\(#function) panel=\(panel)")
        
        let targetPanel: PanelSide = panel == .left ? .left : .right
        let history = appState.navigationHistory(for: targetPanel)
        
        guard let path = history.goForward() else {
            log.debug("\(#function) no history to go forward to")
            return
        }
        
        log.debug("\(#function) goForward returned path=\(path)")
        
        Task {
            appState.isNavigatingFromHistory = true
            do {
                await navigateToPath(path, panel: panel)
            }
            appState.isNavigatingFromHistory = false
        }
    }
    
    func navigateUp(panel: FavPanelSide) {
        log.info("\(#function) panel=\(panel)")
        
        let currentPath = panel == .left ? appState.leftPath : appState.rightPath
        let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        let parentPath = parentURL.path
        
        guard parentPath != currentPath else {
            log.debug("\(#function) already at root")
            return
        }
        
        Task {
            await navigateToPath(parentPath, panel: panel)
        }
    }
    
    func canGoBack(panel: FavPanelSide) -> Bool {
        let targetPanel: PanelSide = panel == .left ? .left : .right
        return appState.navigationHistory(for: targetPanel).canGoBack
    }
    
    func canGoForward(panel: FavPanelSide) -> Bool {
        let targetPanel: PanelSide = panel == .left ? .left : .right
        return appState.navigationHistory(for: targetPanel).canGoForward
    }
    
    func currentPath(for panel: FavPanelSide) -> String {
        panel == .left ? appState.leftPath : appState.rightPath
    }
}

// MARK: - Extension to convert between PanelSide and FavPanelSide
extension PanelSide {
    var toFavPanelSide: FavPanelSide {
        self == .left ? .left : .right
    }
    
    init(from favPanel: FavPanelSide) {
        self = favPanel == .left ? .left : .right
    }
}

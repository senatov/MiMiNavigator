// AppState+Settings.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Settings toggles, panel swap, force refresh.

import AppKit
import FileModelKit
import Foundation

// MARK: - Settings & Panel Swap
extension AppState {

    func toggleShowHiddenFiles() {
        UserPreferences.shared.snapshot.showHiddenFiles.toggle()
        Task {
            await scanner.refreshFiles(currSide: .left)
            await scanner.refreshFiles(currSide: .right)
        }
    }

    func forceRefreshBothPanels() {
        Task {
            await scanner.refreshFiles(currSide: .left)
            await scanner.refreshFiles(currSide: .right)
        }
    }

    /// Active swap task — cancelled on re-entry to prevent stacking.
    private static var swapTask: Task<Void, Never>?

    func swapPanels() {
        log.debug(#function + ": leftPath: \(leftPath), rightPath: \(rightPath)")
        // Cancel any in-flight swap to prevent stacking
        Self.swapTask?.cancel()
        let tmpURL = leftURL
        leftURL = rightURL
        rightURL = tmpURL
        tabManager(for: .left).updateActiveTabPath(leftURL)
        tabManager(for: .right).updateActiveTabPath(rightURL)
        let tmpSel = self[panel: .left].selectedFile
        setSelectedFile(self[panel: .right].selectedFile, for: .left)
        setSelectedFile(tmpSel, for: .right)
        // Swap displayed files instantly (no async wait)
        let tmpFiles = displayedLeftFiles
        displayedLeftFiles = displayedRightFiles
        displayedRightFiles = tmpFiles
        Self.swapTask = Task {
            await scanner.clearCooldown(for: .left)
            await scanner.clearCooldown(for: .right)
            await setScannerDirectory(leftPath, for: .left)
            await setScannerDirectory(rightPath, for: .right)
            guard !Task.isCancelled else { return }
            await refreshFiles(for: .left)
            guard !Task.isCancelled else { return }
            await refreshFiles(for: .right)
        }
    }
}

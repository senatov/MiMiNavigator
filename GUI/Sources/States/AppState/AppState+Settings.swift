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

    func swapPanels() {
        log.debug(#function + ": leftPath: \(leftPath), rightPath: \(rightPath)")
        let tmpURL = leftURL
        leftURL = rightURL
        rightURL = tmpURL
        tabManager(for: .left).updateActiveTabPath(leftURL)
        tabManager(for: .right).updateActiveTabPath(rightURL)
        let tmpSel = self[panel: .left].selectedFile
        setSelectedFile(self[panel: .right].selectedFile, for: .left)
        setSelectedFile(tmpSel, for: .right)
        Task {
            await setScannerDirectory(leftPath, for: .left)
            await setScannerDirectory(rightPath, for: .right)
            await refreshFiles(for: .left)
            await refreshFiles(for: .right)
        }
    }
}

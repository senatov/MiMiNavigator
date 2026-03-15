// AppState+Settings.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Settings toggles, panel swap, force refresh

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
        let tmpPath = leftPath
        leftPath = rightPath
        rightPath = tmpPath
        tabManager(for: .left).updateActiveTabPath(leftURL)
        tabManager(for: .right).updateActiveTabPath(rightURL)
        let tmpSel = selectedLeftFile
        selectedLeftFile = selectedRightFile
        selectedRightFile = tmpSel
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshLeftFiles()
            await refreshRightFiles()
        }
    }
}

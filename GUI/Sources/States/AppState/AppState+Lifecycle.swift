// AppState+Lifecycle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: App lifecycle — initialize, saveBeforeExit, spinner watchdog

import AppKit
import FileModelKit
import Foundation

// MARK: - Lifecycle
extension AppState {

    private func setupSpinnerWatchdog() {
        let watchdog = SpinnerWatchdog.shared
        watchdog.addSource(name: "BatchOperation") { BatchOperationManager.shared.showProgressDialog }
        watchdog.start()
    }

    func initialize() {
        setupSpinnerWatchdog()
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)
        StatePersistence.restoreTabs(into: self)
        StatePersistence.restoreSorting(into: self)
        focusedPanel = .left
        if let cached = PanelStartupCache.shared.load(forLeftPath: leftPath, rightPath: rightPath) {
            displayedLeftFiles = cached.left
            displayedRightFiles = cached.right
            selectedLeftFile = firstRealFile(in: cached.left)
            selectedRightFile = firstRealFile(in: cached.right)
        }
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await scanner.startMonitoring()
            async let l: Void = refreshLeftFiles()
            async let r: Void = refreshRightFiles()
            _ = await (l, r)
            selectionManager?.restoreSelectionsAndFocus()
            focusedPanel = .left
            if selectedLeftFile == nil { selectedLeftFile = firstRealFile(in: displayedLeftFiles) }
            PanelStartupCache.shared.save(
                leftPath: leftPath, rightPath: rightPath,
                leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
        }
    }

    func saveBeforeExit() {
        StatePersistence.saveBeforeExit(from: self)
        PanelStartupCache.shared.save(
            leftPath: leftPath, rightPath: rightPath,
            leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
        Task { await ArchiveManager.shared.cleanup() }
    }
}

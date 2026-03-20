    // AppState+Lifecycle.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 15.03.2026.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: App lifecycle — initialize, saveBeforeExit, spinner watchdog.

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
            StatePersistence.restoreTabs(into: self)
            StatePersistence.restoreSorting(into: self)
            focusedPanel = .left
            if let cached = PanelStartupCache.shared.load(forLeftPath: leftPath, rightPath: rightPath) {
                displayedLeftFiles = cached.left
                displayedRightFiles = cached.right
                setSelectedFile(firstRealFile(in: cached.left), for: .left)
                setSelectedFile(firstRealFile(in: cached.right), for: .right)
            }
            Task { @MainActor in
                await setScannerDirectory(leftPath, for: .left)
                await setScannerDirectory(rightPath, for: .right)
                await scanner.startMonitoring()
                await refreshFiles(for: .left)
                await refreshFiles(for: .right)
                selectionManager?.restoreSelectionsAndFocus()
                focusedPanel = .left
                if self[panel: .left].selectedFile == nil {
                    setSelectedFile(firstRealFile(in: displayedLeftFiles), for: .left)
                }
                PanelStartupCache.shared.save(
                    leftPath: leftPath,
                    rightPath: rightPath,
                    leftFiles: displayedLeftFiles,
                    rightFiles: displayedRightFiles
                )
            }
        }

        func saveBeforeExit() {
            StatePersistence.saveBeforeExit(from: self)
            PanelStartupCache.shared.save(
                leftPath: leftPath, rightPath: rightPath,
                leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
            Task { @MainActor in
                await ArchiveManager.shared.cleanup()
            }
        }
    }

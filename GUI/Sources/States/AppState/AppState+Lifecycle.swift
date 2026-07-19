// AppState+Lifecycle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: App lifecycle — initialize, saveBeforeExit, spinner watchdog.
//   Guard against double-initialization from SwiftUI onAppear re-entry.

import AppKit
import FileModelKit
import Foundation

// MARK: - Lifecycle
extension AppState {

    private static var didInitialize = false

    func initialize() {
        guard !Self.didInitialize else {
            log.debug("[AppState] initialize() skipped — already done")
            return
        }
        Self.didInitialize = true
        log.info("[AppState] initialize() starting")

        StatePersistence.restoreTabs(into: self)
        syncPanelPathsToRestoredTabs()
        StatePersistence.restoreSorting(into: self)
        if let cached = PanelStartupCache.shared.load(forLeftPath: leftPath, rightPath: rightPath) {
            displayedLeftFiles = cached.left
            displayedRightFiles = cached.right
            setSelectedFile(firstRealFile(in: cached.left), for: .left)
            setSelectedFile(firstRealFile(in: cached.right), for: .right)
            log.info("[AppState] startup cache applied: L=\(cached.left.count) R=\(cached.right.count)")
        }
        Task { @MainActor in
            await setScannerDirectory(leftPath, for: .left)
            await setScannerDirectory(rightPath, for: .right)
            await scanner.startMonitoring()
            await refreshFiles(for: .left)
            await refreshFiles(for: .right)
            selectionManager?.restoreSelectionsAndFocus()
            if self[panel: .left].selectedFile == nil {
                setSelectedFile(firstRealFile(in: displayedLeftFiles), for: .left)
            }
            PanelStartupCache.shared.save(
                leftPath: leftPath,
                rightPath: rightPath,
                leftFiles: displayedLeftFiles,
                rightFiles: displayedRightFiles
            )
            AutoFitScheduler.shared.scheduleInitialFit(appState: self)
            startConfigurationAutosave()
            log.info("[AppState] initialize() async scan complete")
        }
    }

    // MARK: - Periodic Configuration Autosave
    func startConfigurationAutosave() {
        configurationAutosaveTask?.cancel()
        lastConfigurationAutosaveFingerprint = configurationAutosaveFingerprint()
        configurationAutosaveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard let self, !Task.isCancelled, !isTerminating else { continue }
                let fingerprint = configurationAutosaveFingerprint()
                guard fingerprint != lastConfigurationAutosaveFingerprint else { continue }
                log.debug("[AppState] configuration changed; saving snapshot")
                saveConfigurationSnapshot()
                lastConfigurationAutosaveFingerprint = fingerprint
            }
        }
    }

    func saveBeforeExit() {
        configurationAutosaveTask?.cancel()
        configurationAutosaveTask = nil
        saveConfigurationSnapshot()
    }

    func saveConfigurationSnapshot() {
        UserPreferences.shared.capture(from: self)
        UserPreferences.shared.synchronize()
        MiMiDefaults.shared.synchronize()
        StatePersistence.saveBeforeExit(from: self)
        PanelStartupCache.shared.save(
            leftPath: leftPath, rightPath: rightPath,
            leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
    }

    private func configurationAutosaveFingerprint() -> String {
        let leftTabs = leftTabManager.tabs.map { "\($0.id.uuidString):\($0.url.path):\($0.viewMode.rawValue)" }.joined(separator: "|")
        let rightTabs = rightTabManager.tabs.map { "\($0.id.uuidString):\($0.url.path):\($0.viewMode.rawValue)" }
            .joined(separator: "|")
        return [
            leftPath,
            rightPath,
            selectedLeftFile?.pathStr ?? "",
            selectedRightFile?.pathStr ?? "",
            String(describing: sortKey),
            String(bSortAscending),
            String(showHiddenFiles),
            leftTabs,
            rightTabs,
        ]
        .joined(separator: "\u{1F}")
    }

    // MARK: - Restore Tab Paths
    private func syncPanelPathsToRestoredTabs() {
        leftURL = leftTabManager.activeTab.url
        rightURL = rightTabManager.activeTab.url
        leftNavigationHistory.navigateTo(leftURL)
        rightNavigationHistory.navigateTo(rightURL)
        log.info("[AppState] restored active tab paths L=\(leftURL.path) R=\(rightURL.path)")
    }
}

//
//  FileTableView+Lifecycle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation

extension FileTableView {
    // MARK: - Lifecycle and Change Handling
    func onAppear() {
        log.debug("[FileTableView] appear panel=\(panelSide) files=\(files.count)")
        log.debug("[Columns] panel=\(panelSide) column count=\(layout.columns.count)")
        recomputeSortedCache()
        registerNavigationCallbacks()
    }

    func handleMenuTrackingBegan() {
        activeMenuTrackingCount += 1
        log.debug("[FileTableView] menu tracking began panel=\(panelSide) depth=\(activeMenuTrackingCount)")
    }

    func handleMenuTrackingEnded() {
        activeMenuTrackingCount = max(0, activeMenuTrackingCount - 1)
        log.debug("[FileTableView] menu tracking ended panel=\(panelSide) depth=\(activeMenuTrackingCount)")

        guard activeMenuTrackingCount == 0, let deferredVersion = deferredFilesVersion else {
            return
        }

        deferredFilesVersion = nil
        log.info("[FileTableView] applying deferred filesVersion panel=\(panelSide) version=\(deferredVersion)")
        recomputeSortedCache()
        scheduleAutoFitIfNeeded()
    }

    func handleSelectionChange(_ newID: CustomFile.ID?) {
        updateSelectedIndex(for: newID)
    }

    func syncSelectionFromState(_ newID: CustomFile.ID?) {
        if selectedID != newID {
            selectedID = newID
        }
    }

    func handleLoadingChange(_ loading: Bool) {
        spinnerTask?.cancel()

        if loading {
            spinnerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                if !Task.isCancelled && isLoading {
                    showSpinner = true
                }
            }
        } else {
            showSpinner = false
        }
    }

    func handleAppDidBecomeActive() {
        guard !appState.isTerminating else {
            log.info("[FileTableView] app-activation refresh skipped panel=\(panelSide) — app is terminating")
            return
        }
        guard !isMenuTracking else {
            log.debug("[FileTableView] app-activation refresh skipped panel=\(panelSide) while menu is open")
            return
        }
        guard !isLoading else {
            log.debug("[FileTableView] app-activation refresh skipped panel=\(panelSide) while loading")
            return
        }
        guard !currentPanelPath.isEmpty else { return }

        log.info("[FileTableView] app became active — refreshing panel=\(panelSide) path='\(currentPanelPath)'")
        Task {
            guard !appState.isTerminating else {
                log.info("[FileTableView] app-activation refresh task cancelled panel=\(panelSide) — app is terminating")
                return
            }
            await appState.scanner.refreshFiles(currSide: panelSide)
        }
    }

    func handleFilesVersionChange(_ newValue: Int) {
        log.debug(
            "[FileTableView] filesVersion changed panel=\(panelSide) new=\(filesVersion) files=\(files.count) menuTracking=\(isMenuTracking)"
        )

        if isMenuTracking {
            deferredFilesVersion = newValue
            log.info("[FileTableView] deferring filesVersion update panel=\(panelSide) version=\(newValue) while menu is open")
            return
        }

        recomputeSortedCache()
        scheduleAutoFitIfNeeded()
    }

    func handleFilesMetadataChange() {
        guard !isMenuTracking else {
            log.debug("[FileTableView] metadata refresh deferred panel=\(panelSide) while menu is open")
            return
        }
        guard !files.isEmpty else { return }

        log.debug("[FileTableView] metadata changed panel=\(panelSide) files=\(files.count)")
        recomputeSortedCache()
    }
}

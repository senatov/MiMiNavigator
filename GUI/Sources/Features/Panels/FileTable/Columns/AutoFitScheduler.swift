// AutoFitScheduler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized autofit scheduler — runs autofit after both panels finish loading.
//   Replaces per-view deferred autofit tasks with a single coordinator that waits for
//   initial scan completion + a settling delay before fitting columns.

import FileModelKit
import Foundation

@MainActor
@Observable
final class AutoFitScheduler {

    static let shared = AutoFitScheduler()

    // MARK: - Config
    /// Delay after both panels loaded before first autofit pass
    private let initialSettleDelay: Duration = .seconds(2)
    /// Delay between subsequent passes
    private let passInterval: Duration = .seconds(2)
    /// Max polls waiting for dir sizes to resolve (500ms each)
    private let maxSizePolls = 60

    // MARK: - State
    private var initialFitTask: Task<Void, Never>?
    private var navigationFitTasks: [FavPanelSide: Task<Void, Never>] = [:]
    private var lastAutoFitPath: [FavPanelSide: String] = [:]
    private var lastAutoFitWidth: [FavPanelSide: CGFloat] = [:]
    private var initialFitDone = false
    private static var lastResizeFitTime: Date = .distantPast

    private init() {}

    // MARK: - Initial Startup Autofit

    /// Called once from AppState.initialize() after scan tasks are launched.
    /// Waits for both panels to finish loading, then runs autofit.
    func scheduleInitialFit(appState: AppState) {
        initialFitTask?.cancel()
        initialFitTask = Task { @MainActor in
            log.info("[AutoFit] initial fit: waiting for both panels to finish loading")

            // poll until both panels have files
            for _ in 0..<120 {
                if Task.isCancelled { return }
                let leftFiles = appState.displayedFiles(for: .left)
                let rightFiles = appState.displayedFiles(for: .right)
                if !leftFiles.isEmpty && !rightFiles.isEmpty { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            if Task.isCancelled { return }

            // settle delay — let dir sizes resolve
            log.info("[AutoFit] initial fit: panels loaded, settling \(self.initialSettleDelay)")
            try? await Task.sleep(for: self.initialSettleDelay)
            if Task.isCancelled { return }

            // wait for dir sizes — left first, then right
            await self.waitForSizesResolved(appState: appState, panel: .left)
            if Task.isCancelled { return }

            // --- LEFT panel: 3 passes ---
            log.info("[AutoFit] initial fit: starting LEFT panel")
            self.runAutoFit(panel: .left, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            self.runAutoFit(panel: .left, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            self.runAutoFit(panel: .left, appState: appState)
            self.lastAutoFitPath[.left] = appState.leftPath
            log.info("[AutoFit] initial fit: LEFT panel done")

            // small gap before right panel
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }

            // --- RIGHT panel: 3 passes ---
            await self.waitForSizesResolved(appState: appState, panel: .right)
            if Task.isCancelled { return }

            log.info("[AutoFit] initial fit: starting RIGHT panel")
            self.runAutoFit(panel: .right, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            self.runAutoFit(panel: .right, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            self.runAutoFit(panel: .right, appState: appState)
            self.lastAutoFitPath[.right] = appState.rightPath

            self.initialFitDone = true
            log.info("[AutoFit] initial fit complete for both panels")
        }
    }

    // MARK: - Navigation Autofit

    /// Called when user navigates to a new directory.
    /// Deferred: waits for sizes to resolve, then runs 3 passes.
    func scheduleNavigationFit(panel: FavPanelSide, appState: AppState) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let currentPath = appState.path(for: panel)
        guard currentPath != lastAutoFitPath[panel] else {
            log.debug("[AutoFit] nav skip — same path panel=\(panel)")
            return
        }
        navigationFitTasks[panel]?.cancel()
        lastAutoFitPath[panel] = currentPath
        log.info("[AutoFit] nav schedule panel=\(panel) path=\(currentPath)")
        navigationFitTasks[panel] = Task { @MainActor in
            // wait for dir sizes
            await self.waitForSizesResolved(appState: appState, panel: panel)
            if Task.isCancelled { return }

            let files = appState.displayedFiles(for: panel)
            log.info("[AutoFit] nav pass 1 panel=\(panel) files=\(files.count)")
            self.runAutoFit(panel: panel, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            log.debug("[AutoFit] nav pass 2 panel=\(panel)")
            self.runAutoFit(panel: panel, appState: appState)

            try? await Task.sleep(for: self.passInterval)
            if Task.isCancelled { return }
            log.debug("[AutoFit] nav pass 3 (final) panel=\(panel)")
            self.runAutoFit(panel: panel, appState: appState)
        }
    }

    // MARK: - Resize Autofit

    /// Called when panel container width changes significantly.
    func handleResize(panel: FavPanelSide, newWidth: CGFloat, appState: AppState) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let files = appState.displayedFiles(for: panel)
        guard !files.isEmpty else { return }
        let lastWidth = lastAutoFitWidth[panel] ?? 0
        let delta = abs(newWidth - lastWidth)
        guard delta > 12 else { return }
        let now = Date()
        guard now.timeIntervalSince(Self.lastResizeFitTime) > 2.0 else { return }
        Self.lastResizeFitTime = now
        log.debug("[AutoFit] resize panel=\(panel) delta=\(Int(delta))pt")
        lastAutoFitWidth[panel] = newWidth
        let layout = ColumnLayoutStore.shared.layout(for: panel)
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
    }

    // MARK: - Helpers

    private func runAutoFit(panel: FavPanelSide, appState: AppState) {
        let layout = ColumnLayoutStore.shared.layout(for: panel)
        let files = appState.displayedFiles(for: panel)
        guard !files.isEmpty else {
            log.debug("[AutoFit] runAutoFit skip — no files panel=\(panel)")
            return
        }
        lastAutoFitWidth[panel] = layout.containerWidth
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
    }


    private func waitForSizesResolved(appState: AppState, panel: FavPanelSide) async {
        for _ in 0..<maxSizePolls {
            if Task.isCancelled { return }
            let files = appState.displayedFiles(for: panel)
            let allResolved = files.allSatisfy { file in
                guard file.isDirectory else { return true }
                if file.sizeIsExact { return true }
                if file.securityState != .normal { return true }
                if file.cachedDirectorySize != nil { return true }
                return false
            }
            if allResolved { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

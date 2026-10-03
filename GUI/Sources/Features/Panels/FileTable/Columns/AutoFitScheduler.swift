// AutoFitScheduler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Event-driven column autofit coordinator for panel content and layout changes.

import FileModelKit
import Foundation

@MainActor
@Observable
final class AutoFitScheduler {

    static let shared = AutoFitScheduler()

    // MARK: - Config
    private let eventCoalescingDelay: Duration = .milliseconds(120)
    private let contentSettleDelay: Duration = .seconds(2)
    private let maximumAutomaticContentFitCount = 500

    // MARK: - State
    private var navigationFitTasks: [FavPanelSide: Task<Void, Never>] = [:]
    private var lastScheduledPath: [FavPanelSide: String] = [:]
    private var lastAutoFitWidth: [FavPanelSide: CGFloat] = [:]
    private var lastResizeFitTime: [FavPanelSide: Date] = [:]
    private var loadingPanels: Set<FavPanelSide> = []

    private init() {}

    // MARK: - Content Autofit

    /// Coalesces scanner publication and later metadata/size events into one fit per event burst.
    func scheduleNavigationFit(panel: FavPanelSide, appState: AppState) {
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else {
            log.debug("[AutoFit] nav deferred while loading panel=\(panel)")
            return
        }
        let path = appState.path(for: panel)
        let isSamePath = lastScheduledPath[panel] == path
        lastScheduledPath[panel] = path
        navigationFitTasks[panel]?.cancel()
        guard isSamePath || UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let delay = isSamePath ? contentSettleDelay : eventCoalescingDelay
        log.debug("[AutoFit] content event panel=\(panel) path=\(path) samePath=\(isSamePath)")
        navigationFitTasks[panel] = Task { @MainActor in
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            guard appState.path(for: panel) == path else { return }
            self.runAutoFit(panel: panel, appState: appState, limitFileCount: isSamePath)
        }
    }

    /// Called after file operations that update the current directory without
    /// navigating away. Unlike navigation fit, same-path publishes are allowed.
    func scheduleContentFit(panel: FavPanelSide, appState: AppState, reason: String) {
        log.debug("[AutoFit] explicit content event panel=\(panel) reason=\(reason)")
        scheduleNavigationFit(panel: panel, appState: appState)
    }

    func prepareForNavigationLoading(panel: FavPanelSide) {
        loadingPanels.insert(panel)
        navigationFitTasks[panel]?.cancel()
        log.debug("[AutoFit] paused for navigation loading panel=\(panel)")
    }

    func preserveMirroredLayout(panel: FavPanelSide, path: String) {
        navigationFitTasks[panel]?.cancel()
        lastAutoFitWidth[panel] = ColumnLayoutStore.shared.layout(for: panel).containerWidth
        log.debug("[AutoFit] preserved mirrored layout panel=\(panel) path=\(path)")
    }

    func setLoading(_ loading: Bool, panel: FavPanelSide, appState: AppState) {
        if loading {
            loadingPanels.insert(panel)
            navigationFitTasks[panel]?.cancel()
            log.debug("[AutoFit] paused panel=\(panel)")
            return
        }
        guard loadingPanels.remove(panel) != nil else { return }
        log.debug("[AutoFit] resumed panel=\(panel)")
        scheduleNavigationFit(panel: panel, appState: appState)
    }

    // MARK: - Sidebar Layout Autofit
    func scheduleSidebarLayoutFit(appState: AppState, reason: String) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        log.info("[AutoFit] sidebar layout schedule reason=\(reason)")
        scheduleNavigationFit(panel: .left, appState: appState)
        scheduleNavigationFit(panel: .right, appState: appState)
    }

    // MARK: - Resize Autofit

    /// Called when panel container width changes significantly.
    /// Guards against resize↔autofit feedback loops: after autofit changes
    /// column widths, SwiftUI may emit a new geometry that differs by ~18pt,
    /// which triggers another autofit, which changes columns again → loop.
    /// We break the loop with a post-autofit grace period.
    private let resizePostAutoFitGrace: TimeInterval = 2.0
    /// Track when last autofit finished to avoid immediate re-trigger
    private var lastAutoFitFinish: [FavPanelSide: Date] = [:]

    func handleResize(panel: FavPanelSide, newWidth: CGFloat, appState: AppState) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else { return }
        let files = appState.displayedFiles(for: panel)
        guard !files.isEmpty else { return }
        let lastWidth = lastAutoFitWidth[panel] ?? 0
        let delta = abs(newWidth - lastWidth)
        guard delta > 12 else { return }
        let now = Date()
        // Debounce rapid resize events
        let lastFitTime = lastResizeFitTime[panel] ?? .distantPast
        guard now.timeIntervalSince(lastFitTime) > 0.35 else { return }
        // Break resize↔autofit feedback loop: skip if autofit just ran
        let lastFinish = lastAutoFitFinish[panel] ?? .distantPast
        guard now.timeIntervalSince(lastFinish) > resizePostAutoFitGrace else { return }
        lastResizeFitTime[panel] = now
        log.debug("[AutoFit] resize panel=\(panel) delta=\(Int(delta))pt")
        lastAutoFitWidth[panel] = newWidth
        let layout = ColumnLayoutStore.shared.layout(for: panel)
        guard !layout.isColumnReorderActive else { return }
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        lastAutoFitFinish[panel] = Date()
    }

    // MARK: - Helpers

    private func runAutoFit(panel: FavPanelSide, appState: AppState, limitFileCount: Bool) {
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else {
            log.debug("[AutoFit] pass skipped while loading panel=\(panel)")
            return
        }
        let layout = ColumnLayoutStore.shared.layout(for: panel)
        guard !layout.isColumnReorderActive else {
            log.debug("[AutoFit] runAutoFit skip — column reorder active panel=\(panel)")
            return
        }
        let files = appState.displayedFiles(for: panel)
        guard !files.isEmpty else {
            log.debug("[AutoFit] runAutoFit skip — no files panel=\(panel)")
            return
        }
        guard !limitFileCount || files.count <= maximumAutomaticContentFitCount else {
            log.debug("[AutoFit] same-path fit skipped panel=\(panel) files=\(files.count)")
            return
        }
        lastAutoFitWidth[panel] = layout.containerWidth
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        lastAutoFitFinish[panel] = Date()
    }

}

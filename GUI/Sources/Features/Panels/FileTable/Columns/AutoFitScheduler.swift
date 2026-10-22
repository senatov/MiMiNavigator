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
    private var pendingNavigationFitPaths: [FavPanelSide: String] = [:]
    private var pendingPresentationFitPaths: [FavPanelSide: String] = [:]
    private var lastScheduledPath: [FavPanelSide: String] = [:]
    private var lastAutoFitWidth: [FavPanelSide: CGFloat] = [:]
    private var lastResizeFitTime: [FavPanelSide: Date] = [:]
    private var loadingPanels: Set<FavPanelSide> = []
    private var visibleRows: [FavPanelSide: (first: Int, count: Int)] = [:]
    private var lastVisibleChange: [FavPanelSide: Date] = [:]
    private var backgroundFitTasks: [FavPanelSide: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Visible Rows
    func updateVisibleRows(first: Int, count: Int, panel: FavPanelSide) {
        let previous = visibleRows[panel]
        guard previous?.first != first || previous?.count != count else { return }
        visibleRows[panel] = (first, count)
        lastVisibleChange[panel] = Date()
    }

    // MARK: - Content Autofit

    /// Coalesces scanner publication and later metadata/size events into one fit per event burst.
    func scheduleNavigationFit(panel: FavPanelSide, appState: AppState) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let path = appState.path(for: panel)
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else {
            log.debug("[AutoFit] nav deferred while loading panel=\(panel)")
            return
        }
        let isSamePath = lastScheduledPath[panel] == path
        lastScheduledPath[panel] = path
        navigationFitTasks[panel]?.cancel()
        navigationFitTasks[panel] = nil
        if !isSamePath {
            pendingNavigationFitPaths[panel] = path
        }
        let isNavigationFit = pendingNavigationFitPaths[panel] == path
        let isPresentationFit = pendingPresentationFitPaths[panel] == path
        let delay = isNavigationFit ? eventCoalescingDelay : contentSettleDelay
        log.debug("[AutoFit] content event panel=\(panel) path=\(path) samePath=\(isSamePath)")
        navigationFitTasks[panel] = Task { @MainActor in
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            self.navigationFitTasks[panel] = nil
            guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
            guard appState.path(for: panel) == path else { return }
            guard self.runAutoFit(panel: panel, appState: appState, limitFileCount: !isNavigationFit && !isPresentationFit) else { return }
            if self.pendingNavigationFitPaths[panel] == path { self.pendingNavigationFitPaths[panel] = nil }
            if self.pendingPresentationFitPaths[panel] == path { self.pendingPresentationFitPaths[panel] = nil }
        }
    }

    // MARK: - Panel Presentation Autofit
    func schedulePresentationFit(panel: FavPanelSide, appState: AppState) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        pendingPresentationFitPaths[panel] = appState.path(for: panel)
        scheduleNavigationFit(panel: panel, appState: appState)
    }

    /// Called after file operations that update the current directory without
    /// navigating away. Unlike navigation fit, same-path publishes are allowed.
    func scheduleContentFit(panel: FavPanelSide, appState: AppState, reason: String) {
        log.debug("[AutoFit] explicit content event panel=\(panel) reason=\(reason)")
        scheduleNavigationFit(panel: panel, appState: appState)
    }

    func prepareForNavigationLoading(panel: FavPanelSide) {
        loadingPanels.insert(panel)
        visibleRows[panel] = nil
        lastVisibleChange[panel] = nil
        navigationFitTasks[panel]?.cancel()
        backgroundFitTasks[panel]?.cancel()
        navigationFitTasks[panel] = nil
        pendingNavigationFitPaths[panel] = nil
        log.debug("[AutoFit] paused for navigation loading panel=\(panel)")
    }

    func preserveMirroredLayout(panel: FavPanelSide, path: String) {
        navigationFitTasks[panel]?.cancel()
        navigationFitTasks[panel] = nil
        pendingNavigationFitPaths[panel] = nil
        lastAutoFitWidth[panel] = ColumnLayoutStore.shared.layout(for: panel).containerWidth
        log.debug("[AutoFit] preserved mirrored layout panel=\(panel) path=\(path)")
    }

    func setLoading(_ loading: Bool, panel: FavPanelSide, appState: AppState) {
        if loading {
            loadingPanels.insert(panel)
            navigationFitTasks[panel]?.cancel()
            backgroundFitTasks[panel]?.cancel()
            navigationFitTasks[panel] = nil
            pendingNavigationFitPaths[panel] = nil
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
        guard newWidth > 0 else { return }
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else { return }
        if pendingNavigationFitPaths[panel] == appState.path(for: panel)
            || pendingPresentationFitPaths[panel] == appState.path(for: panel) {
            scheduleNavigationFit(panel: panel, appState: appState)
            return
        }
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
        guard layout.containerWidth > 0 else { return }
        guard !layout.isColumnReorderActive else { return }
        if files.count >= LargeDirectoryPolicy.largeEntryCount {
            fitLargeDirectory(files, layout: layout, panel: panel, appState: appState)
        } else {
            ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        }
        pendingNavigationFitPaths[panel] = nil
        pendingPresentationFitPaths[panel] = nil
        lastAutoFitFinish[panel] = Date()
    }

    // MARK: - Helpers

    private func runAutoFit(panel: FavPanelSide, appState: AppState, limitFileCount: Bool) -> Bool {
        guard !loadingPanels.contains(panel), !appState.isLoading(panel) else {
            log.debug("[AutoFit] pass skipped while loading panel=\(panel)")
            return false
        }
        let layout = ColumnLayoutStore.shared.layout(for: panel)
        guard layout.containerWidth > 0 else { return false }
        guard !layout.isColumnReorderActive else {
            log.debug("[AutoFit] runAutoFit skip — column reorder active panel=\(panel)")
            return false
        }
        let files = appState.displayedFiles(for: panel)
        guard !files.isEmpty else {
            log.debug("[AutoFit] runAutoFit skip — no files panel=\(panel)")
            return false
        }
        guard !limitFileCount || files.count <= maximumAutomaticContentFitCount else {
            log.debug("[AutoFit] same-path fit skipped panel=\(panel) files=\(files.count)")
            return false
        }
        lastAutoFitWidth[panel] = layout.containerWidth
        if files.count >= LargeDirectoryPolicy.largeEntryCount {
            fitLargeDirectory(files, layout: layout, panel: panel, appState: appState)
        } else {
            ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        }
        lastAutoFitFinish[panel] = Date()
        return true
    }

    // MARK: - Large Directory Fit
    private func fitLargeDirectory(_ files: [CustomFile], layout: ColumnLayoutModel, panel: FavPanelSide, appState: AppState) {
        let position = visibleRows[panel] ?? (first: 0, count: 30)
        let window = LargeDirectoryPolicy.visibleWindow(count: files.count, firstVisible: position.first, visibleCount: position.count)
        let nearby = Array(files[window])
        ColumnAutoFitter.autoFitAll(layout: layout, files: nearby)
        backgroundFitTasks[panel]?.cancel()
        let path = appState.path(for: panel)
        let version = panel == .left ? appState.leftFilesVersion : appState.rightFilesVersion
        backgroundFitTasks[panel] = Task { @MainActor in
            let worker = Task.detached(priority: .utility) {
                LargeDirectoryPolicy.backgroundSample(from: files, excluding: window)
            }
            let remaining = await worker.value
            guard !Task.isCancelled, appState.path(for: panel) == path else { return }
            guard (panel == .left ? appState.leftFilesVersion : appState.rightFilesVersion) == version else { return }
            while Date().timeIntervalSince(lastVisibleChange[panel] ?? .distantPast) < 0.5 {
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled { return }
            }
            guard !loadingPanels.contains(panel), !appState.isLoading(panel) else { return }
            ColumnAutoFitter.autoFitAll(layout: layout, files: nearby + remaining)
            log.debug("[AutoFit] background sample panel=\(panel) total=\(files.count) measured=\(nearby.count + remaining.count)")
        }
    }

}

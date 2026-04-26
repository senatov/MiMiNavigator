// DuoFilePanelView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Main dual-panel file manager view with fixed initial split position

import AppKit
import FileModelKit
import SwiftUI

struct DuoFilePanelView: View {
    // MARK: - Environment & State
    @Environment(AppState.self) var appState
    @Binding var isFinderSidebarVisible: Bool
    @State private var toolbarStore = ToolbarStore.shared  // tracks menuBarVisible changes
    @State private var leftPanelWidth: CGFloat = 0
    @State private var isInitialized = false
    @State private var lastContainerWidth: CGFloat = 0
    @State private var pendingContainerWidth: CGFloat = 0
    @State private var isGeometryUpdateScheduled = false
    @State private var keyboardHandler: DuoFilePanelKeyboardHandler?

    // MARK: - Persisted divider position (via MiMiDefaults JSON storage)

    // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let minPanelWidth: CGFloat = 80
        static let defaultBackingScale: CGFloat = 2.0
        static let finderSidebarWidth: CGFloat = 220
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            if toolbarStore.menuBarVisible {
                DuoPanelTopMenuBarSection(isFinderSidebarVisible: $isFinderSidebarVisible)
            }

            geometrySection

            DuoPanelBottomToolbarSection(
                onRename: { actions.performRename() },
                onView: { actions.performView() },
                onEdit: { actions.performEdit() },
                onCopy: { actions.performCopy() },
                onMove: { actions.performMove() },
                onNewFolder: { actions.performNewFolder() },
                onDelete: { actions.performDelete() },
                onExit: { actions.performExit() }
            )
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onChange(of: leftPanelWidth) { _, newValue in
            guard newValue > 0, isInitialized else { return }
            MiMiDefaults.shared.set(newValue, forKey: "leftPanelWidth")
            MiMiDefaults.shared.set(savedLeftPanelRatio(for: newValue), forKey: "leftPanelWidthRatio")
        }
        .overlay {
            progressOverlay
        }
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if BatchOperationManager.shared.showProgressDialog,
            let state = BatchOperationManager.shared.currentOperation
        {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                BatchProgressDialog(
                    state: state,
                    onCancel: {
                        BatchOpsCoord.shared.cancelCurrentOperation()
                    },
                    onDismiss: {
                        BatchOperationManager.shared.dismissProgressDialog()
                    }
                )
            }
            .transition(.opacity)
            .animation(.easeOut(duration: 0.12), value: BatchOperationManager.shared.showProgressDialog)
        }
    }

    private var geometrySection: some View {
        GeometryReader { geometry in
            let panelWidth = panelsContainerWidth(for: geometry.size.width)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    if isFinderSidebarVisible {
                        FinderSidebarView(appState: appState)
                            .frame(width: Layout.finderSidebarWidth, height: geometry.size.height)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    if leftPanelWidth > 0, panelWidth > 0 {
                        DuoPanelFilePanelsSection(
                            leftPanelWidth: $leftPanelWidth,
                            containerWidth: panelWidth,
                            containerHeight: geometry.size.height,
                            fetchFiles: fetchFiles
                        )
                        .frame(width: panelWidth, height: geometry.size.height)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                Color.clear
                    .onAppear {
                        scheduleGeometryWidthUpdate(panelWidth)
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        scheduleGeometryWidthUpdate(panelsContainerWidth(for: newWidth))
                    }
                    .onChange(of: isFinderSidebarVisible) { _, _ in
                        scheduleGeometryWidthUpdate(panelsContainerWidth(for: geometry.size.width))
                    }
                    .allowsHitTesting(false)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: isFinderSidebarVisible)
    }

    // MARK: - Panels Width
    private func panelsContainerWidth(for totalWidth: CGFloat) -> CGFloat {
        let sidebarWidth = isFinderSidebarVisible ? Layout.finderSidebarWidth : 0
        return max(totalWidth - sidebarWidth, Layout.minPanelWidth * 2 + Layout.dividerHitAreaWidth)
    }

    private func scheduleGeometryWidthUpdate(_ width: CGFloat) {
        guard width > 0 else { return }

        pendingContainerWidth = width
        guard !isGeometryUpdateScheduled else { return }
        isGeometryUpdateScheduled = true

        DispatchQueue.main.async {
            let resolvedWidth = pendingContainerWidth
            pendingContainerWidth = 0
            isGeometryUpdateScheduled = false
            applyGeometryWidthUpdate(resolvedWidth)
        }
    }

    private func applyGeometryWidthUpdate(_ width: CGFloat) {
        guard width > 0 else { return }

        if !isInitialized {
            handleInitialLayout(containerWidth: width)
            return
        }

        handleResize(oldWidth: lastContainerWidth, newWidth: width)
    }

    private func onAppear() {
        log.debug("\(#function) DuoFilePanelView onAppear")
        appState.initialize()
        setupKeyboardHandler()
    }

    private func onDisappear() {
        log.debug("\(#function) DuoFilePanelView onDisappear")
        keyboardHandler?.unregister()
    }

    private func handleInitialLayout(containerWidth: CGFloat) {
        guard containerWidth > 0 else { return }

        if !isInitialized {
            log.debug("\(#function) initializing with containerWidth=\(Int(containerWidth))")
            initializePanelWidth(containerWidth: containerWidth)
            lastContainerWidth = containerWidth
            isInitialized = true
            return
        }

        // Safety: if leftPanelWidth is still 0 after init, re-init
        if leftPanelWidth <= 0 {
            log.warning("\(#function) leftPanelWidth is 0 after init — re-initializing")
            initializePanelWidth(containerWidth: containerWidth)
            lastContainerWidth = containerWidth
        }

        if lastContainerWidth <= 0 {
            lastContainerWidth = containerWidth
        }
    }

    private func handleResize(oldWidth: CGFloat, newWidth: CGFloat) {
        guard isInitialized, newWidth > 0 else { return }

        let trackedOldWidth = lastContainerWidth > 0 ? lastContainerWidth : oldWidth
        guard trackedOldWidth > 0 else {
            lastContainerWidth = newWidth
            return
        }

        if abs(trackedOldWidth - newWidth) < 0.5 {
            lastContainerWidth = newWidth
            return
        }

        let oldAvailableWidth = availablePanelWidth(containerWidth: trackedOldWidth)
        let newAvailableWidth = availablePanelWidth(containerWidth: newWidth)
        guard oldAvailableWidth > 0, newAvailableWidth > 0 else {
            lastContainerWidth = newWidth
            return
        }

        let ratio = min(max(leftPanelWidth / oldAvailableWidth, 0), 1)
        let resizedWidth = calculateConstrainedWidth(
            proposed: newAvailableWidth * ratio,
            containerWidth: newWidth
        )

        log.debug("\(#function) \(Int(trackedOldWidth))→\(Int(newWidth)) ratio=\(String(format: "%.3f", ratio)) left=\(Int(resizedWidth))")

        if abs(leftPanelWidth - resizedWidth) >= 0.5 {
            leftPanelWidth = resizedWidth
        }
        lastContainerWidth = newWidth
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? Layout.defaultBackingScale
    }

    private func availablePanelWidth(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth - Layout.dividerHitAreaWidth, Layout.minPanelWidth * 2)
    }

    private func savedLeftPanelRatio(for width: CGFloat) -> CGFloat {
        let availableWidth = availablePanelWidth(containerWidth: max(width + Layout.dividerHitAreaWidth, 1))
        guard availableWidth > 0 else { return 0.5 }
        return min(max(width / availableWidth, 0), 1)
    }

    private func persistedLeftPanelRatio() -> CGFloat? {
        let savedRatio = MiMiDefaults.shared.double(forKey: "leftPanelWidthRatio")
        guard savedRatio > 0, savedRatio < 1 else { return nil }
        return CGFloat(savedRatio)
    }

    private func persistedLeftPanelWidth(containerWidth: CGFloat) -> CGFloat? {
        if let savedRatio = persistedLeftPanelRatio() {
            return availablePanelWidth(containerWidth: containerWidth) * savedRatio
        }

        let savedWidth = MiMiDefaults.shared.double(forKey: "leftPanelWidth")
        guard savedWidth > 0 else { return nil }
        return CGFloat(savedWidth)
    }

    private func defaultInitialPanelWidth(containerWidth: CGFloat) -> CGFloat {
        let halfCenter = (availablePanelWidth(containerWidth: containerWidth) / 2.0 * screenScale).rounded() / screenScale
        return halfCenter
    }

    // MARK: - Actions Helper
    private var actions: DuoFilePanelActions {
        DuoFilePanelActions(
            appState: appState,
            refreshBothPanels: refreshBothPanels
        )
    }
}

// MARK: - File Operations
extension DuoFilePanelView {
    @MainActor
    private func fetchFiles(for side: FavPanelSide) async {
        log.debug("\(#function) side=\(side)")
        await appState.scanner.refreshFiles(currSide: side)
    }

    @MainActor
    private func refreshBothPanels() async {
        log.debug("\(#function)")
        await fetchFiles(for: .left)
        await fetchFiles(for: .right)
    }
}

// MARK: - Panel Width Management
extension DuoFilePanelView {
    private enum RecoveryKeys {
        static let emergencyDividerResetPending = "window.emergencyDividerResetPending"
    }

    private func initializePanelWidth(containerWidth: CGFloat) {
        log.debug("\(#function) containerWidth=\(Int(containerWidth))")
        guard containerWidth > 0 else {
            log.warning("\(#function) containerWidth is 0, deferring initialization")
            return
        }

        let emergencyResetPending = MiMiDefaults.shared.bool(forKey: RecoveryKeys.emergencyDividerResetPending)
        let proposed: CGFloat

        if emergencyResetPending {
            proposed = defaultInitialPanelWidth(containerWidth: containerWidth)
            MiMiDefaults.shared.removeObject(forKey: RecoveryKeys.emergencyDividerResetPending)
            log.warning("\(#function) emergency window recovery detected — resetting divider to 50/50")
        } else {
            proposed = persistedLeftPanelWidth(containerWidth: containerWidth) ?? defaultInitialPanelWidth(containerWidth: containerWidth)
        }

        if emergencyResetPending {
            log.info("\(#function) using emergency divider fallback: \(Int(proposed))")
        } else if persistedLeftPanelWidth(containerWidth: containerWidth) != nil {
            log.info("\(#function) restoring saved divider from MiMiDefaults: \(Int(proposed))")
        } else {
            log.info("\(#function) no saved divider, using 50/50: \(Int(proposed))")
        }

        let resolvedWidth = calculateConstrainedWidth(
            proposed: proposed,
            containerWidth: containerWidth
        )
        if abs(leftPanelWidth - resolvedWidth) >= 0.5 {
            leftPanelWidth = resolvedWidth
        }
        log.info("\(#function) → leftPanelWidth=\(Int(resolvedWidth))")
    }

    private func calculateConstrainedWidth(proposed: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let maxWidth = containerWidth - Layout.minPanelWidth - Layout.dividerHitAreaWidth
        let snapped = (proposed * screenScale).rounded() / screenScale
        let result = min(max(snapped, Layout.minPanelWidth), maxWidth)
        log.debug("\(#function) proposed=\(Int(proposed)) max=\(Int(maxWidth)) → result=\(Int(result))")
        return result
    }
}

// MARK: - Keyboard Shortcuts
extension DuoFilePanelView {
    private func setupKeyboardHandler() {
        log.debug("\(#function)")
        let actions = actions
        let handler = DuoFilePanelKeyboardHandler(appState: appState)
        handler.onView = { actions.performView() }
        handler.onEdit = { actions.performEdit() }
        handler.onCopy = { actions.performCopy() }
        handler.onMove = { actions.performMove() }
        handler.onNewFolder = { actions.performNewFolder() }
        handler.onDelete = { actions.performDelete() }
        handler.onExit = { actions.performExit() }
        handler.onFindFiles = { [appState] in
            let panel = appState.focusedPanel
            let searchPath = appState.path(for: panel)
            let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
            FindFilesCoordinator.shared.toggle(
                searchPath: searchPath,
                selectedFile: selectedFile,
                appState: appState
            )
        }
        handler.onOpenSelected = { appState.openSelectedItem() }
        handler.onRefreshPanels = { appState.forceRefreshBothPanels() }
        handler.onToggleHiddenFiles = { appState.toggleShowHiddenFiles() }
        handler.onOpenSettings = {
            HotKeySettingsCoordinator.shared.showSettings()
        }
        handler.onRenameFile = { actions.performRename() }
        handler.register()
        keyboardHandler = handler
        log.debug("\(#function) keyboard handler registered")
    }
}

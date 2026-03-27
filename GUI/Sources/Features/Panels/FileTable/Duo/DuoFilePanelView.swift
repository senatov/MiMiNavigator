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
    @State private var toolbarStore = ToolbarStore.shared  // tracks menuBarVisible changes
    @State private var leftPanelWidth: CGFloat = 0
    @State private var isInitialized = false
    @State private var keyboardHandler: DuoFilePanelKeyboardHandler?

    // MARK: - Persisted divider position (via MiMiDefaults JSON storage)

    // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let minPanelWidth: CGFloat = 80
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            if toolbarStore.menuBarVisible {
                DuoPanelTopMenuBarSection()
            }

            geometrySection

            DuoPanelBottomToolbarSection(
                onView: { actions.performView() },
                onEdit: { actions.performEdit() },
                onCopy: { actions.performCopy() },
                onMove: { actions.performMove() },
                onNewFolder: { actions.performNewFolder() },
                onDelete: { actions.performDelete() },
                onSettings: { actions.performSettings() },
                onConsole: { actions.performConsole() },
                onExit: { actions.performExit() }
            )
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onChange(of: leftPanelWidth) { _, newValue in
            guard newValue > 0, isInitialized else { return }
            MiMiDefaults.shared.set(newValue, forKey: "leftPanelWidth")
        }
        .overlay {
            progressOverlay
        }
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if BatchOperationManager.shared.showProgressDialog,
           let state = BatchOperationManager.shared.currentOperation {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                BatchProgressDialog(
                    state: state,
                    onCancel: {
                        BatchOperationCoordinator.shared.cancelCurrentOperation()
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
            DuoPanelFilePanelsSection(
                leftPanelWidth: $leftPanelWidth,
                containerWidth: geometry.size.width,
                containerHeight: geometry.size.height,
                fetchFiles: fetchFiles
            )
            .onAppear {
                handleInitialLayout(containerWidth: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { oldWidth, newWidth in
                handleResize(oldWidth: oldWidth, newWidth: newWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if !isInitialized {
            log.debug("\(#function) initializing with containerWidth=\(Int(containerWidth))")
            initializePanelWidth(containerWidth: containerWidth)
            isInitialized = true
        }
    }

    private func handleResize(oldWidth: CGFloat, newWidth: CGFloat) {
        guard isInitialized, oldWidth > 0 else { return }

        let ratio = leftPanelWidth / oldWidth
        let newLeftWidth = calculateConstrainedWidth(
            proposed: newWidth * ratio,
            containerWidth: newWidth
        )
        leftPanelWidth = newLeftWidth
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
    private func initializePanelWidth(containerWidth: CGFloat) {
        log.debug("\(#function) containerWidth=\(Int(containerWidth))")
        guard containerWidth > 0 else {
            log.warning("\(#function) containerWidth is 0, deferring initialization")
            return
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        // Use persisted divider position if available
        let proposed: CGFloat
        let savedWidth = MiMiDefaults.shared.double(forKey: "leftPanelWidth")
        if savedWidth > 0 {
            proposed = CGFloat(savedWidth)
            log.info("\(#function) restoring saved divider from MiMiDefaults: \(Int(proposed))")
        } else {
            let halfCenter = (containerWidth / 2.0 * scale).rounded() / scale
            proposed = halfCenter - Layout.dividerHitAreaWidth / 2
            log.info("\(#function) no saved divider, using 50/50: \(Int(proposed))")
        }
        leftPanelWidth = calculateConstrainedWidth(
            proposed: proposed,
            containerWidth: containerWidth
        )
        log.info("\(#function) → leftPanelWidth=\(Int(leftPanelWidth))")
    }

    private func calculateConstrainedWidth(proposed: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let maxWidth = containerWidth - Layout.minPanelWidth - Layout.dividerHitAreaWidth
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let snapped = (proposed * scale).rounded() / scale
        let result = min(max(snapped, Layout.minPanelWidth), maxWidth)
        log.debug("\(#function) proposed=\(Int(proposed)) max=\(Int(maxWidth)) → result=\(Int(result))")
        return result
    }
}

// MARK: - Keyboard Shortcuts
extension DuoFilePanelView {
    private func setupKeyboardHandler() {
        log.debug("\(#function)")
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
        handler.register()
        keyboardHandler = handler
        log.debug("\(#function) keyboard handler registered")
    }
}

// DuoFilePanelView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.10.2025.
// Refactored: 04.02.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Main dual-panel file manager view with fixed initial split position

import AppKit
import SwiftUI

struct DuoFilePanelView: View {
    // MARK: - Environment & State
    @Environment(AppState.self) var appState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var isInitialized = false
    @State private var keyboardHandler: DuoFilePanelKeyboardHandler?

    // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let minPanelWidth: CGFloat = 80
        static let defaultSplitRatio: CGFloat = 0.5 // 50/50 split
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            DuoPanelTopMenuBarSection()
            
            GeometryReader { geometry in
                DuoPanelFilePanelsSection(
                    leftPanelWidth: $leftPanelWidth,
                    containerWidth: geometry.size.width,
                    containerHeight: geometry.size.height,
                    fetchFiles: fetchFiles
                )
                .onAppear {
                    // Initialize panel width INSIDE GeometryReader where we have actual container size
                    if !isInitialized {
                        log.debug("\(#function) onAppear: initializing with containerWidth=\(Int(geometry.size.width))")
                        initializePanelWidth(containerWidth: geometry.size.width)
                        isInitialized = true
                    }
                }
                .onChange(of: geometry.size.width) { oldWidth, newWidth in
                    // Maintain split ratio when window resizes
                    if isInitialized && oldWidth > 0 {
                        let ratio = leftPanelWidth / oldWidth
                        let newLeftWidth = calculateConstrainedWidth(
                            proposed: newWidth * ratio,
                            containerWidth: newWidth
                        )
                        log.debug("\(#function) resize: \(Int(oldWidth))→\(Int(newWidth)) ratio=\(String(format: "%.2f", ratio)) newLeft=\(Int(newLeftWidth))")
                        leftPanelWidth = newLeftWidth
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
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
        .onAppear {
            log.debug("\(#function) DuoFilePanelView onAppear")
            appState.initialize()
            setupKeyboardHandler()
        }
        .onDisappear {
            log.debug("\(#function) DuoFilePanelView onDisappear")
            keyboardHandler?.unregister()
        }
        .onChange(of: leftPanelWidth) { _, newValue in
            // Save only valid widths
            if newValue > 0 && isInitialized {
                UserDefaults.standard.set(newValue, forKey: "leftPanelWidth")
            }
        }
        // Batch operation progress overlay
        .overlay {
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
                .animation(.easeOut(duration: 0.15), value: BatchOperationManager.shared.showProgressDialog)
            }
        }
        // Find Files is now a standalone window (see FindFilesCoordinator)
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
    private func fetchFiles(for side: PanelSide) async {
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
    /// Initialize panel width using CONTAINER width, not screen width
    /// This fixes the bug where divider goes to wrong position on first launch
    private func initializePanelWidth(containerWidth: CGFloat) {
        log.debug("\(#function) containerWidth=\(Int(containerWidth))")
        
        guard containerWidth > 0 else {
            log.warning("\(#function) containerWidth is 0, deferring initialization")
            return
        }
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Calculate 50/50 split based on CONTAINER width (not screen width!)
        let halfCenter = (containerWidth / 2.0 * scale).rounded() / scale
        let defaultLeftWidth = halfCenter - Layout.dividerHitAreaWidth / 2
        
        // Check if we have a saved width
        if let savedWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat,
           savedWidth > 0 {
            // Validate and constrain saved width to current container
            let constrainedSaved = calculateConstrainedWidth(
                proposed: savedWidth,
                containerWidth: containerWidth
            )
            leftPanelWidth = constrainedSaved
            log.info("\(#function) restored saved width=\(Int(constrainedSaved)) (original=\(Int(savedWidth)))")
        } else {
            // No saved width -> use 50/50 default
            let constrainedDefault = calculateConstrainedWidth(
                proposed: defaultLeftWidth,
                containerWidth: containerWidth
            )
            leftPanelWidth = constrainedDefault
            log.info("\(#function) using default 50/50 width=\(Int(constrainedDefault))")
        }
        
        log.debug("\(#function) RESULT: container=\(Int(containerWidth)) scale=\(scale) halfCenter=\(Int(halfCenter)) finalLeft=\(Int(leftPanelWidth))")
    }
    
    /// Calculate constrained width within valid bounds
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
        handler.onFindFiles = {
            FindFilesCoordinator.shared.toggle(
                searchPath: appState.focusedPanel == .left ? appState.leftPath : appState.rightPath
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

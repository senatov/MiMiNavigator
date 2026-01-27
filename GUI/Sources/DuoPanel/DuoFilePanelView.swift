// DuoFilePanelView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.10.2025.
// Refactored: 27.01.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Main dual-panel file manager view

import AppKit
import SwiftUI

struct DuoFilePanelView: View {
    // MARK: - Environment & State
    @Environment(AppState.self) var appState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var keyboardHandler: DuoFilePanelKeyboardHandler?

    // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let minPanelWidth: CGFloat = 80
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
            appState.initialize()
            initializePanelWidth()
            setupKeyboardHandler()
        }
        .onDisappear {
            keyboardHandler?.unregister()
        }
        .onChange(of: leftPanelWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "leftPanelWidth")
        }
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
        log.debug("fetchFiles for \(side)")
        await appState.scanner.refreshFiles(currSide: side)
    }
    
    @MainActor
    private func refreshBothPanels() async {
        await fetchFiles(for: .left)
        await fetchFiles(for: .right)
    }
}

// MARK: - Panel Width Management
extension DuoFilePanelView {
    private func initializePanelWidth() {
        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width
        let scale = screen.backingScaleFactor
        let centerX = (screenWidth / 2.0 * scale).rounded() / scale
        let defaultLeftWidth = centerX - Layout.dividerHitAreaWidth / 2
        let maxWidth = screenWidth - Layout.minPanelWidth - Layout.dividerHitAreaWidth
        let constrainedWidth = min(max(defaultLeftWidth, Layout.minPanelWidth), maxWidth)
        
        if let savedWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat {
            leftPanelWidth = min(max(savedWidth, Layout.minPanelWidth), maxWidth)
        } else {
            leftPanelWidth = constrainedWidth
        }
    }
}

// MARK: - Keyboard Shortcuts
extension DuoFilePanelView {
    private func setupKeyboardHandler() {
        let handler = DuoFilePanelKeyboardHandler(appState: appState)
        handler.onView = { actions.performView() }
        handler.onEdit = { actions.performEdit() }
        handler.onCopy = { actions.performCopy() }
        handler.onMove = { actions.performMove() }
        handler.onNewFolder = { actions.performNewFolder() }
        handler.onDelete = { actions.performDelete() }
        handler.onExit = { actions.performExit() }
        handler.register()
        keyboardHandler = handler
    }
}

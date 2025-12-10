//
// DuoFilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

struct DuoFilePanelView: View {
    // MARK: - Environment & State
    @Environment(AppState.self) var appState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var keyMonitor: Any?

    // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let minPanelWidth: CGFloat = 80
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Top menu bar
            DuoPanelTopMenuBarSection()
            
            // File panels with geometry reader
            GeometryReader { geometry in
                DuoPanelFilePanelsSection(
                    leftPanelWidth: $leftPanelWidth,
                    containerWidth: geometry.size.width,
                    containerHeight: geometry.size.height,
                    fetchFiles: fetchFiles
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom toolbar
            DuoPanelBottomToolbarSection(
                onView: performView,
                onEdit: performEdit,
                onCopy: performCopy,
                onMove: performMove,
                onNewFolder: performNewFolder,
                onDelete: performDelete,
                onSettings: performSettings,
                onConsole: performConsole,
                onExit: performExit
            )
        }
        .onAppear {
            appState.initialize()
            initializePanelWidth()
            registerKeyboardShortcuts()
        }
        .onDisappear {
            unregisterKeyboardShortcuts()
        }
        .onChange(of: leftPanelWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "leftPanelWidth")
        }
    }
}

// MARK: - File Operations
extension DuoFilePanelView {
    // MARK: -
    @MainActor
    private func fetchFiles(for side: PanelSide) async {
        log.debug(#function + "for \(side)")
        switch side {
            case .left:
                appState.displayedLeftFiles = await appState.scanner.fileLst.getLeftFiles()
            case .right:
                appState.displayedRightFiles = await appState.scanner.fileLst.getRightFiles()
        }
    }

    // MARK: -
    private func performView() {
        log.debug(#function + "View button pressed")
        guard let file = appState.selectedLeftFile else { return }
        FActions.view(file)
    }

    // MARK: -
    private func performEdit() {
        log.debug(#function + "Edit button pressed")
        guard let file = appState.selectedLeftFile else { return }
        FActions.edit(file)
    }

    // MARK: -
    private func performCopy() {
        log.debug(#function + "Copy button pressed")
        guard let source = currentSelectedFile,
            let destination = targetPanelURL
        else { return }
        FActions.copy(source, to: destination)
        Task { await appState.refreshFiles() }
    }

    // MARK: -
    private func performMove() {
        log.debug(#function + "Move button pressed")
    }

    // MARK: -
    private func performNewFolder() {
        log.debug(#function + "New Folder button pressed")
    }

    // MARK: -
    private func performDelete() {
        log.debug(#function + "Delete button pressed")
        guard let file = appState.selectedLeftFile else { return }
        FActions.deleteWithConfirmation(file) {
            Task {
                await fetchFiles(for: .left)
                await fetchFiles(for: .right)
            }
        }
    }

    // MARK: -
    private func performSettings() {
        log.debug(#function + "Settings button pressed")
    }

    // MARK: -
    private func performConsole() {
        log.debug(#function + "Console button pressed")
        let path = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
        _ = ConsoleCurrPath.open(in: path)
    }

    // MARK: -
    private func performExit() {
        log.debug(#function + "Exit button pressed")
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Computed Properties (Data only, not Views)
extension DuoFilePanelView {
    // MARK: -
    private var currentSelectedFile: CustomFile? {
        appState.focusedPanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
    }
    
    // MARK: -
    private var targetPanelURL: URL? {
        let targetSide: PanelSide = appState.focusedPanel == .left ? .right : .left
        return appState.pathURL(for: targetSide)
    }
}

// MARK: - Panel Width Management
extension DuoFilePanelView {
    // MARK: -
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
    private func registerKeyboardShortcuts() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            self.handleKeyEvent(event, appState: appState)
        }
    }

    private func unregisterKeyboardShortcuts() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent, appState: AppState?) -> NSEvent? {
        if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
            appState?.saveBeforeExit()
            NSApplication.shared.terminate(nil)
            return nil
        }

        if event.keyCode == 0x30 {
            appState?.toggleFocus()
            return nil
        }

        return event
    }
}

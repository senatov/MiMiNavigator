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
    // MARK: - Fetch files (triggers actual directory scan)
    @MainActor
    private func fetchFiles(for side: PanelSide) async {
        log.debug(#function + " for \(side)")
        // Call refreshFiles which actually scans the directory
        // and updates both the cache and displayedLeftFiles/displayedRightFiles
        await appState.scanner.refreshFiles(currSide: side)
    }

    // MARK: - F3 View
    private func performView() {
        log.debug(#function + " View button pressed")
        
        // Check VS Code first
        guard FActions.isVSCodeInstalled() else {
            FActions.promptVSCodeInstall { }
            return
        }
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for View")
            return
        }
        
        // Don't view directories
        guard !file.isDirectory else {
            log.debug("Cannot view directory")
            return
        }
        
        FActions.view(file)
    }

    // MARK: - F4 Edit
    private func performEdit() {
        log.debug(#function + " Edit button pressed")
        
        // Check VS Code first
        guard FActions.isVSCodeInstalled() else {
            FActions.promptVSCodeInstall { }
            return
        }
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for Edit")
            return
        }
        
        // Don't edit directories
        guard !file.isDirectory else {
            log.debug("Cannot edit directory")
            return
        }
        
        FActions.edit(file)
    }

    // MARK: - F5 Copy
    private func performCopy() {
        log.debug(#function + " Copy button pressed")
        
        guard let source = currentSelectedFile else {
            log.debug("No file selected for Copy")
            return
        }
        
        guard let destination = targetPanelURL else {
            log.debug("No destination panel available")
            return
        }
        
        FActions.copyWithConfirmation(source, to: destination) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F6 Move
    private func performMove() {
        log.debug(#function + " Move button pressed")
        
        guard let source = currentSelectedFile else {
            log.debug("No file selected for Move")
            return
        }
        
        guard let destination = targetPanelURL else {
            log.debug("No destination panel available")
            return
        }
        
        FActions.moveWithConfirmation(source, to: destination) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F7 New Folder
    private func performNewFolder() {
        log.debug(#function + " New Folder button pressed")
        
        guard let currentURL = appState.pathURL(for: appState.focusedPanel) else {
            log.debug("No current directory for New Folder")
            return
        }
        
        FActions.createFolderWithDialog(at: currentURL) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F8 Delete
    private func performDelete() {
        log.debug(#function + " Delete button pressed")
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for Delete")
            return
        }
        
        FActions.deleteWithConfirmation(file) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - Settings
    private func performSettings() {
        log.debug(#function + " Settings button pressed")
        // TODO: Implement settings panel
    }

    // MARK: - Console
    private func performConsole() {
        log.debug(#function + " Console button pressed")
        let path = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
        _ = ConsoleCurrPath.open(in: path)
    }

    // MARK: - Exit
    private func performExit() {
        log.debug(#function + " Exit button pressed")
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Helper: Refresh panels
    @MainActor
    private func refreshBothPanels() async {
        await fetchFiles(for: .left)
        await fetchFiles(for: .right)
    }
    
    @MainActor
    private func refreshCurrentPanel() async {
        await fetchFiles(for: appState.focusedPanel)
    }
}

// MARK: - Computed Properties
extension DuoFilePanelView {
    // MARK: - Current selected file from focused panel
    private var currentSelectedFile: CustomFile? {
        appState.focusedPanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
    }
    
    // MARK: - Target panel URL (opposite of focused)
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

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
        }
    }

    private func unregisterKeyboardShortcuts() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Log key events for debugging
        log.debug("[KEY] keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers.rawValue)")
        
        // Tab: Toggle focus between panels
        if keyCode == 0x30 {  // Tab
            appState.toggleFocus()
            return nil
        }
        
        // Option+F4: Exit
        if modifiers.contains(.option) && keyCode == 0x76 {  // F4
            performExit()
            return nil
        }
        
        // Function keys - check for Fn modifier or no modifiers
        // macOS may or may not report .function depending on keyboard settings
        let hasOnlyFnOrNone = modifiers.subtracting([.function, .numericPad]).isEmpty
        
        if hasOnlyFnOrNone {
            switch keyCode {
            case 0x63:  // F3
                log.info("[KEY] F3 pressed → View")
                performView()
                return nil
            case 0x76:  // F4
                log.info("[KEY] F4 pressed → Edit")
                performEdit()
                return nil
            case 0x60:  // F5
                log.info("[KEY] F5 pressed → Copy")
                performCopy()
                return nil
            case 0x61:  // F6
                log.info("[KEY] F6 pressed → Move")
                performMove()
                return nil
            case 0x62:  // F7
                log.info("[KEY] F7 pressed → NewFolder")
                performNewFolder()
                return nil
            case 0x64:  // F8
                log.info("[KEY] F8 pressed → Delete")
                performDelete()
                return nil
            default:
                break
            }
        }

        return event
    }
}

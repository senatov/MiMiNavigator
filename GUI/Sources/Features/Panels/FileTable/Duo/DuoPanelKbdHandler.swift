    // DuoFilePanelKeyboardHandler.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 27.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Keyboard shortcuts handler — uses HotKeyStore for configurable bindings

    import AppKit
    import Foundation

    /// Handles keyboard shortcuts for the dual-panel file manager.
    /// All bindings are resolved through HotKeyStore, making them user-configurable.
    @MainActor
    final class DuoFilePanelKeyboardHandler {
        private var keyMonitor: Any?
        private weak var appState: AppState?

        // Action callbacks — set by DuoFilePanelView during setup
        var onView: (() -> Void)?
        var onEdit: (() -> Void)?
        var onCopy: (() -> Void)?
        var onMove: (() -> Void)?
        var onNewFolder: (() -> Void)?
        var onDelete: (() -> Void)?
        var onExit: (() -> Void)?
        var onFindFiles: (() -> Void)?
        var onOpenSelected: (() -> Void)?
        var onParentDirectory: (() -> Void)?
        var onRefreshPanels: (() -> Void)?
        var onToggleHiddenFiles: (() -> Void)?
        var onOpenSettings: (() -> Void)?

        init(appState: AppState) {
            self.appState = appState
        }

        // MARK: - Registration

        func register() {
            guard keyMonitor == nil else { return }

            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
        }

        func unregister() {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }

        // MARK: - Key Event Handling

        private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState else { return event }

            // When a modal dialog is active, pass ALL events to SwiftUI
            // so that TextField, buttons (.keyboardShortcut(.defaultAction)),
            // and Esc (.cancelAction) work correctly.
            if ContextMenuCoordinator.shared.activeDialog != nil {
                return event
            }


            // When text field is focused, let it handle the event
            // (fixes Backspace/Delete not working in text fields)
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            let keyCode = event.keyCode
            let modifiers = event.modifierFlags

            log.debug("[KEY] keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers.rawValue)")

            // Shift+Up/Down: mark current file and move selection (Finder-style multi-select)
            // Must be handled BEFORE HotKeyStore lookup, because HotKeyStore only has
            // unmodified Up/Down bindings and won't match Shift+Arrow.
            let cleanMods = modifiers.intersection(.deviceIndependentFlagsMask)
                .subtracting([.function, .numericPad])
            if cleanMods == .shift {
                if keyCode == 0x7E { // Shift+Up
                    appState.markCurrentAndMove(direction: -1)
                    return nil
                } else if keyCode == 0x7D { // Shift+Down
                    appState.markCurrentAndMove(direction: 1)
                    return nil
                }
            }

            // Lookup action in HotKeyStore
            let store = HotKeyStore.shared
            if let action = store.action(forKeyCode: keyCode, modifiers: modifiers) {
                return dispatch(action: action, appState: appState, event: event)
            }

            // Fallback: Space for toggle mark (special — not easily represented as a simple binding
            // because Space also needs to work in text fields, etc.)
            if keyCode == 0x31 && cleanMods.isEmpty {
                log.info("[KEY] Space → Toggle mark")
                appState.toggleMarkAndMoveNext()
                return nil
            }

            return event
        }

        // MARK: - Action Dispatch

        /// Dispatches a resolved HotKeyAction to the appropriate callback or AppState method.
        /// Returns nil if the event was consumed, or the original event if not.
        private func dispatch(action: HotKeyAction, appState: AppState, event: NSEvent) -> NSEvent? {
            switch action {

            // ── File Operations ──
            case .viewFile:
                log.info("[KEY] → View")
                onView?()
                return nil

            case .editFile:
                log.info("[KEY] → Edit")
                onEdit?()
                return nil

            case .copyFile:
                log.info("[KEY] → Copy")
                onCopy?()
                return nil

            case .moveFile:
                log.info("[KEY] → Move")
                onMove?()
                return nil

            case .newFolder:
                log.info("[KEY] → NewFolder")
                onNewFolder?()
                return nil

            case .deleteFile:
                log.info("[KEY] → Delete")
                onDelete?()
                return nil

            // ── Navigation ──
            case .togglePanelFocus:
                appState.toggleFocus()
                return nil

            // Arrow keys + PgUp/PgDown/Home/End — dispatch directly to TableKeyboardNavigation
            // via AppState. Cannot rely on returning event to SwiftUI .onKeyPress because
            // NSEvent local monitors run before the SwiftUI responder chain,
            // and SwiftUI may not have focus on the correct view.
            case .moveUp:
                appState.navigateUp()
                return nil
            case .moveDown:
                appState.navigateDown()
                return nil
            case .pageUp:
                appState.navigatePageUp()
                return nil
            case .pageDown:
                appState.navigatePageDown()
                return nil
            case .moveToTop:
                appState.navigateToFirst()
                return nil
            case .moveToBottom:
                appState.navigateToLast()
                return nil

            case .openSelected:
                log.info("[KEY] → Open Selected")
                onOpenSelected?()
                return nil

            case .parentDirectory:
                log.info("[KEY] → Parent Directory")
                onParentDirectory?()
                return nil

            case .refreshPanels:
                log.info("[KEY] → Refresh")
                onRefreshPanels?()
                return nil

            // ── Selection ──
            case .toggleMark:
                log.info("[KEY] → Toggle mark")
                appState.toggleMarkAndMoveNext()
                return nil

            case .markByPattern:
                log.info("[KEY] → Mark by pattern")
                appState.markByPattern()
                return nil

            case .unmarkByPattern:
                log.info("[KEY] → Unmark by pattern")
                appState.unmarkByPattern()
                return nil

            case .invertMarks:
                log.info("[KEY] → Invert marks")
                appState.invertMarks()
                return nil

            case .markAll:
                log.info("[KEY] → Mark all")
                appState.markAll()
                return nil

            case .unmarkAll:
                // ESC is intercepted earlier by onKeyPress(.escape) in FileTableView.
                // This branch handles the unmarkAll action when bound to a non-ESC key.
                log.info("[KEY] → Unmark all")
                appState.unmarkAll()
                appState.ensureSelectionOnFocusedPanel()
                return nil

            case .clearSelection:
                // Clear marks; keep at least the topmost file selected
                log.info("[KEY] → Clear selection")
                appState.unmarkAll()
                appState.ensureSelectionOnFocusedPanel()
                return nil

            case .markSameExtension:
                log.info("[KEY] → Mark same extension")
                appState.markSameExtension()
                return nil

            // ── Tabs ──
            case .newTab:
                log.info("[KEY] → New Tab")
                handleNewTab(appState: appState)
                return nil

            case .closeTab:
                log.info("[KEY] → Close Tab")
                handleCloseTab(appState: appState)
                return nil

            case .nextTab:
                log.info("[KEY] → Next Tab")
                appState.tabManager(for: appState.focusedPanel).selectNextTab()
                syncPanelToActiveTab(appState: appState)
                return nil

            case .prevTab:
                log.info("[KEY] → Previous Tab")
                appState.tabManager(for: appState.focusedPanel).selectPreviousTab()
                syncPanelToActiveTab(appState: appState)
                return nil

            // ── Search ──
            case .findFiles:
                log.info("[KEY] → Find Files")
                onFindFiles?()
                return nil

            // ── Application ──
            case .toggleHiddenFiles:
                log.info("[KEY] → Toggle hidden files")
                onToggleHiddenFiles?()
                return nil

            case .openSettings:
                log.info("[KEY] → Open Settings")
                onOpenSettings?()
                return nil

            case .exitApp:
                log.info("[KEY] → Exit")
                onExit?()
                return nil
            }
        }

        // MARK: - Tab Helpers

        /// Opens a new tab with the selected file/directory or current path
        private func handleNewTab(appState: AppState) {
            let panel = appState.focusedPanel
            let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
            let currentPath = panel == .left ? appState.leftPath : appState.rightPath

            let targetURL: URL
            if let file = selectedFile {
                if file.isDirectory || file.isSymbolicDirectory {
                    targetURL = file.urlValue.resolvingSymlinksInPath()
                } else if file.isArchiveFile {
                    // Archive — delegate to context menu handler for archive opening
                    log.info("[KEY] newTab on archive: '\(file.nameStr)'")
                    ContextMenuCoordinator.shared.openFileInNewTab(file, panel: panel, appState: appState)
                    return
                } else {
                    // Regular file — open containing directory
                    targetURL = file.urlValue.deletingLastPathComponent()
                }
            } else {
                targetURL = URL(fileURLWithPath: currentPath)
            }

            let mgr = appState.tabManager(for: panel)
            mgr.addTab(url: targetURL)
            log.info("[KEY] newTab panel=\(panel) path='\(targetURL.path)'")
            syncPanelToActiveTab(appState: appState)
        }

        /// Closes the active tab on focused panel
        private func handleCloseTab(appState: AppState) {
            let panel = appState.focusedPanel
            let mgr = appState.tabManager(for: panel)

            guard mgr.tabs.count > 1 else {
                log.debug("[KEY] closeTab: only one tab, ignoring")
                return
            }

            mgr.closeActiveTab()
            log.info("[KEY] closeTab panel=\(panel) remaining=\(mgr.tabs.count)")
            syncPanelToActiveTab(appState: appState)
        }

        /// Syncs panel path/scanner to the currently active tab
        private func syncPanelToActiveTab(appState: AppState) {
            let panel = appState.focusedPanel
            let mgr = appState.tabManager(for: panel)
            let tab = mgr.activeTab

            Task { @MainActor in
                let url = tab.url
                appState.updatePath(url, for: panel)
                if panel == .left {
                    await appState.scanner.setLeftDirectory(pathStr: url.path)
                    await appState.scanner.refreshFiles(currSide: .left)
                    await appState.refreshLeftFiles()
                } else {
                    await appState.scanner.setRightDirectory(pathStr: url.path)
                    await appState.scanner.refreshFiles(currSide: .right)
                    await appState.refreshRightFiles()
                }
            }
        }
    }

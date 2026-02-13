// DuoFilePanelKeyboardHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 10.02.2026
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

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        log.debug("[KEY] keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers.rawValue)")

        // Lookup action in HotKeyStore
        let store = HotKeyStore.shared
        if let action = store.action(forKeyCode: keyCode, modifiers: modifiers) {
            return dispatch(action: action, appState: appState, event: event)
        }

        // Fallback: Space for toggle mark (special — not easily represented as a simple binding
        // because Space also needs to work in text fields, etc.)
        let cleanMods = modifiers.intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
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

        case .moveUp:
            appState.selectionMove(by: -1)
            return nil

        case .moveDown:
            appState.selectionMove(by: 1)
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
            // If there are marks → unmark all
            // If no marks → clear file selection
            let markedCount = appState.markedCount(for: appState.focusedPanel)
            if markedCount > 0 {
                log.info("[KEY] → Unmark all")
                appState.unmarkAll()
            } else {
                log.info("[KEY] → Clear selection (ESC with no marks)")
                appState.clearFileSelection()
            }
            return nil

        case .clearSelection:
            log.info("[KEY] → Clear selection")
            appState.clearFileSelection()
            return nil

        case .markSameExtension:
            log.info("[KEY] → Mark same extension")
            appState.markSameExtension()
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
}

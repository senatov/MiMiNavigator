// DuoFilePanelKeyboardHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard shortcuts handler for dual-panel view

import AppKit
import Foundation

/// Handles keyboard shortcuts for the dual-panel file manager
/// Extracted from DuoFilePanelView to separate concerns
@MainActor
final class DuoFilePanelKeyboardHandler {
    private var keyMonitor: Any?
    private weak var appState: AppState?
    
    // Action callbacks
    var onView: (() -> Void)?
    var onEdit: (() -> Void)?
    var onCopy: (() -> Void)?
    var onMove: (() -> Void)?
    var onNewFolder: (() -> Void)?
    var onDelete: (() -> Void)?
    var onExit: (() -> Void)?
    var onFindFiles: (() -> Void)?
    
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
        guard let appState = appState else { return event }
        
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        log.debug("[KEY] keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers.rawValue)")
        
        // MARK: - Multi-Selection Keys (Total Commander style)
        
        // Insert/Help key (or Space) - toggle mark and move next
        if keyCode == KeyCodes.insert || keyCode == KeyCodes.help {
            log.info("[KEY] Insert pressed → Toggle mark")
            appState.toggleMarkAndMoveNext()
            return nil
        }
        
        // Space - toggle mark (alternative to Insert)
        if keyCode == KeyCodes.space && modifiers.isEmpty {
            log.info("[KEY] Space pressed → Toggle mark")
            appState.toggleMarkAndMoveNext()
            return nil
        }
        
        // Numpad + (mark by pattern)
        if keyCode == KeyCodes.numpadPlus && modifiers.isEmpty {
            log.info("[KEY] Num+ pressed → Mark by pattern")
            appState.markByPattern()
            return nil
        }
        
        // Numpad - (unmark by pattern)
        if keyCode == KeyCodes.numpadMinus && modifiers.isEmpty {
            log.info("[KEY] Num- pressed → Unmark by pattern")
            appState.unmarkByPattern()
            return nil
        }
        
        // Numpad * (invert marks)
        if keyCode == KeyCodes.numpadMultiply && modifiers.isEmpty {
            log.info("[KEY] Num* pressed → Invert marks")
            appState.invertMarks()
            return nil
        }
        
        // Cmd+A - mark all
        if keyCode == KeyCodes.keyA && modifiers == .command {
            log.info("[KEY] Cmd+A pressed → Mark all")
            appState.markAll()
            return nil
        }
        
        // Escape - clear marks if any, otherwise let it pass
        if keyCode == KeyCodes.escape && modifiers.isEmpty {
            let markedCount = appState.markedCount(for: appState.focusedPanel)
            if markedCount > 0 {
                log.info("[KEY] Escape pressed → Clear marks")
                appState.unmarkAll()
                return nil
            }
        }
        
        // MARK: - Navigation and Panel Control
        
        // Tab: Toggle focus between panels
        if keyCode == KeyCodes.tab {
            appState.toggleFocus()
            return nil
        }
        
        // Option+F7: Find Files (Total Commander standard)
        if modifiers.contains(.option) && keyCode == KeyCodes.f7 {
            log.info("[KEY] Alt+F7 pressed → Find Files")
            onFindFiles?()
            return nil
        }

        // Option+F4: Exit
        if modifiers.contains(.option) && keyCode == KeyCodes.f4 {
            onExit?()
            return nil
        }
        
        // MARK: - Function Keys (F3-F8)
        
        let hasOnlyFnOrNone = modifiers.subtracting([.function, .numericPad]).isEmpty
        
        if hasOnlyFnOrNone {
            switch keyCode {
            case KeyCodes.f3:
                log.info("[KEY] F3 pressed → View")
                onView?()
                return nil
            case KeyCodes.f4:
                log.info("[KEY] F4 pressed → Edit")
                onEdit?()
                return nil
            case KeyCodes.f5:
                log.info("[KEY] F5 pressed → Copy")
                onCopy?()
                return nil
            case KeyCodes.f6:
                log.info("[KEY] F6 pressed → Move")
                onMove?()
                return nil
            case KeyCodes.f7:
                log.info("[KEY] F7 pressed → NewFolder")
                onNewFolder?()
                return nil
            case KeyCodes.f8:
                log.info("[KEY] F8 pressed → Delete")
                onDelete?()
                return nil
            default:
                break
            }
        }
        
        return event
    }
}

// MARK: - Key Codes
private enum KeyCodes {
    // Navigation
    static let tab: UInt16 = 0x30
    static let escape: UInt16 = 0x35
    static let space: UInt16 = 0x31
    
    // Letters
    static let keyA: UInt16 = 0x00
    
    // Function keys
    static let f3: UInt16 = 0x63
    static let f4: UInt16 = 0x76
    static let f5: UInt16 = 0x60
    static let f6: UInt16 = 0x61
    static let f7: UInt16 = 0x62
    static let f8: UInt16 = 0x64
    
    // Insert/Help (Total Commander style marking)
    static let insert: UInt16 = 0x72  // Insert key (on extended keyboards)
    static let help: UInt16 = 0x72    // Help key (same as Insert on Mac)
    
    // Numpad keys
    static let numpadPlus: UInt16 = 0x45     // Numpad +
    static let numpadMinus: UInt16 = 0x4E    // Numpad -
    static let numpadMultiply: UInt16 = 0x43 // Numpad *
}

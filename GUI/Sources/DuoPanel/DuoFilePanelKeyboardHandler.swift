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
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        log.debug("[KEY] keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers.rawValue)")
        
        // Tab: Toggle focus between panels
        if keyCode == KeyCodes.tab {
            appState?.toggleFocus()
            return nil
        }
        
        // Option+F4: Exit
        if modifiers.contains(.option) && keyCode == KeyCodes.f4 {
            onExit?()
            return nil
        }
        
        // Function keys - check for Fn modifier or no modifiers
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
    static let tab: UInt16 = 0x30
    static let f3: UInt16 = 0x63
    static let f4: UInt16 = 0x76
    static let f5: UInt16 = 0x60
    static let f6: UInt16 = 0x61
    static let f7: UInt16 = 0x62
    static let f8: UInt16 = 0x64
}

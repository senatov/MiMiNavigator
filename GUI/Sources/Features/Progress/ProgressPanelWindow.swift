// ProgressPanelWindow.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSPanel subclass that reports direct user interaction.

import AppKit

// MARK: - ProgressPanelWindow

final class ProgressPanelWindow: NSPanel {
    var onInteraction: (() -> Void)?
    var onPrimaryMouseDown: ((NSEvent) -> Void)?
    var onPrimaryMouseUp: ((NSEvent) -> Void)?

    // MARK: - Send Event
    override func sendEvent(_ event: NSEvent) {
        if Self.isUserInteraction(event) {
            onInteraction?()
        }
        if event.type == .leftMouseDown {
            onPrimaryMouseDown?(event)
        }
        super.sendEvent(event)
        if event.type == .leftMouseUp {
            onPrimaryMouseUp?(event)
        }
    }

    // MARK: - Interaction Filter
    private static func isUserInteraction(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown,
             .leftMouseDown,
             .leftMouseUp,
             .leftMouseDragged,
             .rightMouseDown,
             .rightMouseUp,
             .rightMouseDragged,
             .otherMouseDown,
             .otherMouseUp,
             .otherMouseDragged,
             .mouseMoved,
             .scrollWheel:
            return true
        default:
            return false
        }
    }
}

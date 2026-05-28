// ProgressPanel+Actions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ProgressPanel user actions and event handling.

import AppKit

// MARK: - Actions

extension ProgressPanel {
    private static let interactionEventMask: NSEvent.EventTypeMask = [
        .keyDown,
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
        .scrollWheel
    ]

    // MARK: - Copy to Clipboard
    func copyAllToClipboard() {
        guard let text = logTextView?.string, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log.debug("[ProgressPanel] copied log to clipboard")
    }

    // MARK: - Copy All
    @objc func copyAll() {
        copyAllToClipboard()
    }

    // MARK: - Action Button
    @objc func actionButtonTapped() {
        lastActionButtonActionTime = Date().timeIntervalSince1970
        log.debug("[ProgressPanel] action button tapped finished=\(isFinished)")
        if isFinished {
            hide()
            return
        }
        cancelAutoCloseTimer()
        isCancelled = true
        statusLabel?.stringValue = "Cancelling... operation will stop at the next safe point"
        actionButton?.title = "OK"
        actionButton?.keyEquivalent = "\r"
        actionButton?.isEnabled = true
        applyActionButtonStyle(.confirm)
        isFinished = true
        progressIndicator?.stopAnimation(nil)
        onCancel?()
        log.debug("[ProgressPanel] cancel requested")
    }

    // MARK: - Mouse Down Fallback
    func handlePanelMouseDownFallback(_ event: NSEvent) {
        guard isMouseInsideActionButton(event) else { return }
        let elapsed = Date().timeIntervalSince1970 - lastActionButtonActionTime
        guard elapsed > 0.15 else { return }
        log.debug("[ProgressPanel] action button window fallback fired")
        actionButtonTapped()
    }

    // MARK: - Mouse Up Fallback
    func handlePanelMouseUpFallback(_ event: NSEvent) {
        guard isMouseInsideActionButton(event) else { return }
        let elapsed = Date().timeIntervalSince1970 - lastActionButtonActionTime
        guard elapsed > 0.15 else { return }
        log.debug("[ProgressPanel] action button fallback fired")
        actionButtonTapped()
    }

    // MARK: - Event Monitor
    func installEventMonitorIfNeeded() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.interactionEventMask) { [weak self] event in
            guard let self else { return event }
            let type = event.type
            let keyCode = event.keyCode
            let windowNumber = event.windowNumber
            let keepEvent = MainActor.assumeIsolated {
                self.handleInteraction(type: type, keyCode: keyCode, windowNumber: windowNumber)
            }
            return keepEvent ? event : nil
        }
    }

    // MARK: - Remove Event Monitor
    func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    // MARK: - Handle Interaction
    func handleInteraction(type: NSEvent.EventType, keyCode: UInt16, windowNumber: Int) -> Bool {
        guard panel?.isVisible == true else { return true }
        if isPanelInteraction(windowNumber: windowNumber) {
            registerUserInteraction(source: "event-monitor")
        }
        if type == .keyDown, isFinished {
            return handleKeyEvent(keyCode: keyCode)
        }
        return true
    }

    // MARK: - Action Button Hit Test
    func isMouseInsideActionButton(_ event: NSEvent) -> Bool {
        guard let button = actionButton,
              button.window === event.window
        else { return false }
        let location = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(location)
    }

    // MARK: - Panel Interaction
    func isPanelInteraction(windowNumber: Int) -> Bool {
        guard let panel else { return false }
        if windowNumber == panel.windowNumber {
            return true
        }
        return panel.frame.contains(NSEvent.mouseLocation)
    }

    // MARK: - Handle Key Event
    func handleKeyEvent(keyCode: UInt16) -> Bool {
        let isReturn = keyCode == 36 || keyCode == 76
        let isEscape = keyCode == 53
        if isReturn || isEscape {
            hide()
            return false
        }
        return true
    }
}

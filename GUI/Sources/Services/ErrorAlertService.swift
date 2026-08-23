// ErrorAlertService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized decision dialogs and non-blocking error banners.
//   All methods are @MainActor to avoid blocking MainActor from other contexts.
//   Use 'show' for one-button info/error alerts.
//   Use 'confirm' for two-button yes/no confirmations.

import AppKit
import Foundation

// MARK: - ErrorAlertService

@MainActor
enum ErrorAlertService {

    // MARK: - Simple error / info alert (one button)

    /// Present a one-way error or informational message without blocking the user.
    static func show(
        title: String,
        message: String,
        style: NSAlert.Style = .warning
    ) {
        log.warning("\(#function) '\(title)' — \(message.prefix(120))")
        let isCritical = style == .critical
        InAppNoticeCenter.shared.showBanner(
            title: title,
            message: message,
            systemImage: isCritical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill",
            tint: isCritical ? .red : .orange
        )
    }

    // MARK: - Two-button confirmation

    /// Show a warning alert with two buttons, returns true if first button clicked.
    static func confirm(
        title: String,
        message: String,
        confirmButton: String,
        cancelButton: String = "Cancel",
        style: NSAlert.Style = .warning
    ) async -> Bool {
        log.debug("\(#function) '\(title)'")
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)
        return await response(for: alert) == .alertFirstButtonReturn
    }

    // MARK: - Password prompt (archive unlock)

    /// Alert with a secure text field. Returns entered password or nil if cancelled.
    static func promptPassword(
        archiveName: String,
        confirmButton: String = "Open",
        openWithAppButton: String = "Open with App",
        cancelButton: String = "Cancel"
    ) async -> (password: String?, openWithApp: Bool) {
        log.debug("\(#function) archive='\(archiveName)'")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Password Required"
        alert.informativeText = "\"\(archiveName)\" is password-protected.\nEnter password to open:"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Enter password"
        alert.accessoryView = field
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: openWithAppButton)
        alert.addButton(withTitle: cancelButton)
        alert.window.initialFirstResponder = field
        let resp = await response(for: alert)
        switch resp {
        case .alertFirstButtonReturn:
            let pwd = field.stringValue
            return (pwd.isEmpty ? nil : pwd, false)
        case .alertSecondButtonReturn:
            return (nil, true)
        default:
            return (nil, false)
        }
    }

    // MARK: - Text Prompt
    static func promptText(
        title: String,
        message: String,
        initialValue: String,
        placeholder: String,
        confirmButton: String,
        cancelButton: String = "Cancel"
    ) async -> String? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = initialValue
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)
        alert.window.initialFirstResponder = field
        guard await response(for: alert) == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    // MARK: - Multiple Choice
    static func choose(
        title: String,
        message: String,
        buttons: [String],
        style: NSAlert.Style = .informational
    ) async -> Int? {
        guard !buttons.isEmpty else { return nil }
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        let response = await response(for: alert)
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return buttons.indices.contains(index) ? index : nil
    }

    // MARK: - Window-Scoped Response
    private static func response(for alert: NSAlert) async -> NSApplication.ModalResponse {
        guard let parent = presentationWindow else { return alert.runModal() }
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: parent) { response in
                continuation.resume(returning: response)
            }
        }
    }

    private static var presentationWindow: NSWindow? {
        if let keyWindow = NSApp.keyWindow, keyWindow.isVisible { return keyWindow }
        if let mainWindow = NSApp.mainWindow, mainWindow.isVisible { return mainWindow }
        return NSApp.orderedWindows.first { $0.isVisible && !($0 is NSPanel && $0.hidesOnDeactivate) }
    }
}

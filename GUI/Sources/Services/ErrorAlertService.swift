// ErrorAlertService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized NSAlert helpers — replaces scattered runModal() calls.
//   All methods are @MainActor to avoid blocking MainActor from other contexts.
//   Use 'show' for one-button info/error alerts.
//   Use 'confirm' for two-button yes/no confirmations.

import AppKit
import Foundation

// MARK: - ErrorAlertService

@MainActor
enum ErrorAlertService {

    // MARK: - Simple error / info alert (one button)

    /// Show a warning or critical alert with a single OK button.
    /// Non-blocking from caller's perspective — just fire and forget if you don't need the result.
    @discardableResult
    static func show(
        title: String,
        message: String,
        style: NSAlert.Style = .warning,
        button: String = "OK"
    ) -> NSApplication.ModalResponse {
        log.warning("\(#function) '\(title)' — \(message.prefix(120))")
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        return alert.runModal()
    }

    // MARK: - Two-button confirmation

    /// Show a warning alert with two buttons, returns true if first button clicked.
    static func confirm(
        title: String,
        message: String,
        confirmButton: String,
        cancelButton: String = "Cancel",
        style: NSAlert.Style = .warning
    ) -> Bool {
        log.debug("\(#function) '\(title)'")
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Password prompt (archive unlock)

    /// Alert with a secure text field. Returns entered password or nil if cancelled.
    static func promptPassword(
        archiveName: String,
        confirmButton: String = "Open",
        openWithAppButton: String = "Open with App",
        cancelButton: String = "Cancel"
    ) -> (password: String?, openWithApp: Bool) {
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
        let resp = alert.runModal()
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
}

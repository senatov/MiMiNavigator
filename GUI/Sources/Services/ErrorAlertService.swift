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

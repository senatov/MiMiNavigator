// CloudOAuthRecoveryPolicy.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: User-approved recovery policy for inaccessible or rejected cloud OAuth credentials.

import AppKit

// MARK: - CloudOAuthProvider

enum CloudOAuthProvider: String {
    case dropbox = "Dropbox"
    case googleDrive = "Google Drive"
}

// MARK: - CloudOAuthRecoveryPolicy

@MainActor
enum CloudOAuthRecoveryPolicy {
    // MARK: - Request Credential Reset

    static func requestCredentialReset(for provider: CloudOAuthProvider, reason: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reconnect (provider.rawValue)?"
        alert.informativeText = "(reason)\n\nMiMiNavigator can remove its saved (provider.rawValue) authorization and open the browser to sign in again. Your cloud files and account password will not be deleted. macOS may ask for permission to update Keychain."
        alert.addButton(withTitle: "Reconnect")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

// CloudOAuthRecoveryPolicy.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: User-approved recovery policy for inaccessible or rejected cloud OAuth credentials.

// MARK: - CloudOAuthProvider

enum CloudOAuthProvider: String {
    case dropbox = "Dropbox"
    case googleDrive = "Google Drive"
}

// MARK: - CloudOAuthRecoveryPolicy

@MainActor
enum CloudOAuthRecoveryPolicy {
    // MARK: - Request Credential Reset

    static func requestCredentialReset(for provider: CloudOAuthProvider, reason: String) async -> Bool {
        await ErrorAlertService.confirm(
            title: "Reconnect \(provider.rawValue)?",
            message: "\(reason)\n\nMiMiNavigator can remove its saved \(provider.rawValue) authorization and open the browser to sign in again. Your cloud files and account password will not be deleted. macOS may ask for permission to update Keychain.",
            confirmButton: "Reconnect",
            style: .warning
        )
    }
}

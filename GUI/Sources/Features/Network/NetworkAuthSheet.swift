// NetworkAuthSheet.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal sheet for entering SMB/FTP/SFTP credentials.
//              Saves to Keychain on confirm, calls onAuthenticated to retry share fetch.

import SwiftUI

// MARK: - Auth sheet: user + password entry for a network host
struct NetworkAuthSheet: View {

    let host: NetworkHost
    var onAuthenticated: () -> Void
    var onCancel: () -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSaving: Bool = false
    @State private var isPasswordVisible: Bool = false
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    private var canConfirm: Bool {
        !username.isEmpty && !isSaving
    }

    private var resolvedFocusField: Field {
        username.isEmpty ? .username : .password
    }

    private var passwordPrompt: String {
        "Required"
    }

    // MARK: - Pre-fill from Keychain; purge stale "No user account" ghost entries
    private func isStaleSavedCredentials(_ creds: NetworkCredentials) -> Bool {
        creds.user.isEmpty || creds.user.lowercased().contains("no user")
    }

    private func applySavedCredentials(_ creds: NetworkCredentials) {
        username = creds.user
        password = creds.password
    }

    private func prefill() {
        if let saved = NetworkAuthService.load(for: host.hostName) {
            if isStaleSavedCredentials(saved) {
                NetworkAuthService.delete(for: host.hostName)
                log.info("[Auth] purged stale Keychain entry for \(host.hostName)")
            } else {
                applySavedCredentials(saved)
            }
        }

        isPasswordVisible = false
        focusedField = resolvedFocusField
    }

    // MARK: - Save + callback
    private func scheduleAuthenticationCompletion() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            completeAuthentication()
        }
    }

    private func completeAuthentication() {
        isSaving = false
        onAuthenticated()
    }

    private func confirm() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }

        username = trimmedUsername
        isSaving = true
        let creds = NetworkCredentials(user: trimmedUsername, password: password)
        NetworkAuthService.save(creds, for: host.hostName)
        log.info("[Auth] credentials confirmed for \(host.hostName)")
        scheduleAuthenticationCompletion()
    }

    // MARK: -
    var body: some View {
        VStack(spacing: NetworkAuthSheetLayout.sectionSpacing) {
            NetworkAuthHostCard(host: host)
            NetworkAuthCredentialsSection(
                username: $username,
                password: $password,
                isPasswordVisible: $isPasswordVisible,
                focusedField: $focusedField,
                passwordPrompt: passwordPrompt,
                onConfirm: confirm
            )
            NetworkAuthButtonRow(
                canConfirm: canConfirm,
                isSaving: isSaving,
                onCancel: onCancel,
                onConfirm: confirm
            )
        }
        .frame(width: NetworkAuthSheetLayout.dialogWidth)
        .padding(.vertical, 2)
        .background(NetworkAuthSheetGlassStyle.sheetBackground)
        .glassEffect(.regular)
        .overlay(NetworkAuthSheetGlassStyle.sheetBorder)
        .clipShape(RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous))
        .onAppear { prefill() }
    }
}

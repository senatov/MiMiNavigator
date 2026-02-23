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
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    // MARK: -
    var body: some View {
        VStack(spacing: 0) {
            hostCard
            Divider()
            fieldsSection
            Divider()
            buttonRow
        }
        .frame(width: 360)
        .background(DialogColors.base)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { prefill() }
    }

    // MARK: - Host card (matches HostNodeRow style)
    private var hostCard: some View {
        HStack(spacing: 10) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 22))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to \"\(host.name)\"")
                    .font(.subheadline.weight(.semibold))
                Text(host.hostName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !host.deviceLabel.isEmpty {
                Text(host.deviceLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(DialogColors.stripe)
    }

    // MARK: - Input fields
    private var fieldsSection: some View {
        VStack(spacing: 10) {
            fieldRow(label: "Username", systemImage: "person") {
                TextField("guest", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
            }
            fieldRow(label: "Password", systemImage: "lock") {
                SecureField("Required", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .onSubmit { confirm() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    // MARK: - Single labeled field row
    @ViewBuilder
    private func fieldRow(label: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            content()
        }
    }

    // MARK: - Buttons
    private var buttonRow: some View {
        HStack(spacing: 10) {
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                confirm()
            } label: {
                if isSaving {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Connecting…")
                    }
                } else {
                    Label("Sign In", systemImage: "key.fill")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(username.isEmpty || isSaving)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(DialogColors.stripe)
    }

    // MARK: - Pre-fill from Keychain; purge stale "No user account" ghost entries
    private func prefill() {
        if let saved = NetworkAuthService.load(for: host.hostName) {
            if saved.user.isEmpty || saved.user.lowercased().contains("no user") {
                NetworkAuthService.delete(for: host.hostName)
                log.info("[Auth] purged stale Keychain entry for \(host.hostName)")
            } else {
                username = saved.user
                password = saved.password
            }
        }
        focusedField = username.isEmpty ? .username : .password
    }

    // MARK: - Save + callback
    private func confirm() {
        guard !username.isEmpty else { return }
        isSaving = true
        let creds = NetworkCredentials(user: username, password: password)
        NetworkAuthService.save(creds, for: host.hostName)
        log.info("[Auth] credentials confirmed for \(host.hostName)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSaving = false
            onAuthenticated()
        }
    }
}

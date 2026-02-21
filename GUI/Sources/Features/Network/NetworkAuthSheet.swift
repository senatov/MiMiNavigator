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
        VStack(alignment: .leading, spacing: 16) {
            header
            fields
            buttons
        }
        .padding(20)
        .frame(width: 340)
        .onAppear { prefill() }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to \"\(host.name)\"")
                    .font(.headline)
                Text(host.hostName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Input fields
    private var fields: some View {
        VStack(spacing: 10) {
            LabeledField(label: "Username") {
                TextField("guest", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
            }
            LabeledField(label: "Password") {
                SecureField("Required", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .onSubmit { confirm() }
            }
        }
    }

    // MARK: - Buttons
    private var buttons: some View {
        HStack {
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
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
                    Text("Connect")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(username.isEmpty || isSaving)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Pre-fill from Keychain if available
    private func prefill() {
        if let saved = NetworkAuthService.load(for: host.hostName) {
            username = saved.user
            password = saved.password
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

// MARK: - Simple label+field layout helper
private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    // MARK: -
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

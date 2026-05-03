//
//  ConnToSrvrView+Form.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Form Rows
extension ConnToSrvrView {

    var nameRow: some View {
        SettingsRow(
            label: "Name:",
            help: "Bookmark name for this server. Paste a URL here to auto-fill all fields.",
            labelWidth: 120
        ) {
            TextField("or paste URL: sftp://user@host:port/path", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .name)
                .onChange(of: draft.name) { _, newValue in
                    if applyURLParserIfNeeded(newValue, clearName: true) {
                        return
                    }
                    if !newValue.isEmpty {
                        nameWasManuallyEdited = true
                    }
                }
        }
    }

    var protocolRow: some View {
        SettingsRow(label: "Protocol:", help: "Connection protocol", labelWidth: 120) {
            Picker("", selection: $draft.remoteProtocol) {
                ForEach(RemoteProtocol.allCases) { proto in
                    Text(proto.rawValue).tag(proto)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .glassEffect()
            .onChange(of: draft.remoteProtocol) { _, newProto in
                if shouldReplacePortForProtocolChange {
                    draft.port = newProto.defaultPort
                }
            }
        }
    }

    var hostRow: some View {
        SettingsRow(label: "Host:", help: "Hostname, IP, or paste full URL/connection string", labelWidth: 120) {
            TextField("host  or  user@host:port  or  ftp://host/path", text: $draft.host)
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .host)
                .onChange(of: draft.host) { _, newValue in
                    handleHostChanged(newValue)
                }
                .onSubmit {
                    draft.host = Self.sanitizeHost(draft.host)
                }
        }
    }

    var portRow: some View {
        SettingsRow(label: "Port:", help: "Server port number", labelWidth: 120) {
            TextField("", value: $draft.port, formatter: Self.portFormatter)
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .port)
                .frame(width: 80)
        }
    }

    var remotePathRow: some View {
        SettingsRow(label: "Remote Path:", help: "Initial directory on server", labelWidth: 120) {
            TextField("", text: $draft.remotePath)
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .remotePath)
        }
    }

    var userRow: some View {
        SettingsRow(label: "User:", help: "Login username", labelWidth: 120) {
            TextField("", text: $draft.user)
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .user)
        }
    }

    var passwordRow: some View {
        SettingsRow(label: "Password:", help: "Login password", labelWidth: 120) {
            HStack(spacing: 6) {
                passwordField
                passwordVisibilityButton
                keepPasswordToggle
            }
        }
    }

    @ViewBuilder
    var passwordField: some View {
        if showPassword {
            TextField("", text: $password)
                .id("plain-password-field")
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .password)
        } else {
            SecureField("", text: $password)
                .id("secure-password-field")
                .textFieldStyle(.roundedBorder)
                .glassEffect()
                .focused($focusedField, equals: .password)
        }
    }

    var passwordVisibilityButton: some View {
        Button {
            let shouldRestoreFocus = focusedField == .password
            showPassword.toggle()
            if shouldRestoreFocus {
                Task { @MainActor in
                    focusedField = .password
                }
            }
        } label: {
            Image(systemName: showPassword ? "eye.slash" : "eye")
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
        .buttonStyle(.plain)
        .glassEffect()
        .help(showPassword ? "Hide password" : "Show password")
    }

    var keepPasswordToggle: some View {
        Toggle("Keep", isOn: $keepPassword)
            .toggleStyle(.checkbox)
    }

    var authenticateRow: some View {
        SettingsRow(label: "Authenticate:", help: "Authentication method", labelWidth: 120) {
            Picker("", selection: $draft.authType) {
                ForEach(RemoteAuthType.allCases) { auth in
                    Text(auth.rawValue).tag(auth)
                }
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
            .glassEffect()
        }
    }

    var keyPathRow: some View {
        SettingsRow(label: "Key Path:", help: "Path to SSH private key", labelWidth: 120) {
            HStack(spacing: 6) {
                TextField("", text: $draft.privateKeyPath)
                    .textFieldStyle(.roundedBorder)
                    .glassEffect()
                    .focused($focusedField, equals: .keyPath)

                Button("Choose…", action: chooseKeyFile)
                    .controlSize(.small)
                    .glassEffect()
            }
        }
    }

    var startupRow: some View {
        SettingsRow(label: "Startup:", help: "Automatically connect when MiMiNavigator starts", labelWidth: 120) {
            Toggle("Connect when app starts", isOn: $draft.connectOnStart)
                .toggleStyle(.checkbox)
        }
    }

    var shouldReplacePortForProtocolChange: Bool {
        draft.port == 0 || RemoteProtocol.allCases.map(\.defaultPort).contains(draft.port)
    }
}

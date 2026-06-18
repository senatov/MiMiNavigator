// SettingsCloudLinkPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings pane for Cloud Share+Link credentials.

import AppKit
import SwiftUI

// MARK: - SettingsCloudLinkPane

struct SettingsCloudLinkPane: View {
    @State private var googleClientSecret = ""
    @State private var googleRefreshToken = ""
    @State private var dropboxRefreshToken = ""
    @State private var tinyURLAPIToken = ""
    @State private var statusMessage = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Google client secret:", help: "Desktop OAuth client secret stored in ~/.mimi/google_drive_oauth.json", labelWidth: 170) {
                        SecureField("client_secret", text: $googleClientSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                    Divider()
                    SettingsRow(label: "Google refresh token:", help: "Google Drive refresh token stored in ~/.mimi/cloud_link_credentials.json", labelWidth: 170) {
                        SecureField("refresh_token", text: $googleRefreshToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Dropbox refresh token:", help: "Dropbox OAuth refresh token stored in ~/.mimi/cloud_link_credentials.json", labelWidth: 170) {
                        SecureField("refresh_token", text: $dropboxRefreshToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "TinyURL API token:", help: "TinyURL API token stored in ~/.mimi/cloud_link_credentials.json. Leave empty to use bundled fallback.", labelWidth: 170) {
                        SecureField("api-token", text: $tinyURLAPIToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Save") { saveSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Reload") { loadSettings() }
                Button("Clear tokens") { clearTokens() }
                Spacer()
                Button("Reveal ~/.mimi") { revealMimiDirectory() }
            }
            statusRow
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: statusMessage.hasPrefix("Saved") ? "checkmark.circle" : "info.circle")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Text(statusMessage.isEmpty ? "Credentials are read from ~/.mimi before Keychain." : statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.top, 4)
    }

    // MARK: - Load Settings

    private func loadSettings() {
        googleClientSecret = GoogleDriveCredentialBootstrap.localClientSecret()
        do {
            let credentials = try CloudLinkCredentialsStore.load()
            googleRefreshToken = credentials.googleDriveRefreshToken ?? ""
            dropboxRefreshToken = credentials.dropboxRefreshToken ?? ""
            tinyURLAPIToken = credentials.tinyURLAPIToken ?? ""
            statusMessage = "Loaded local credentials from \(CloudLinkCredentialsStore.path)."
        } catch {
            statusMessage = "Failed to load local credentials: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Settings

    private func saveSettings() {
        do {
            try GoogleDriveCredentialBootstrap.saveLocalClientSecret(googleClientSecret)
            try CloudLinkCredentialsStore.setToken(googleRefreshToken, for: .googleDriveRefreshToken)
            try CloudLinkCredentialsStore.setToken(dropboxRefreshToken, for: .dropboxRefreshToken)
            try CloudLinkCredentialsStore.setToken(tinyURLAPIToken, for: .tinyURLAPIToken)
            statusMessage = "Saved credentials to ~/.mimi."
        } catch {
            statusMessage = "Failed to save credentials: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear Tokens

    private func clearTokens() {
        do {
            try GoogleDriveTokenStore.deleteRefreshToken(ignoreMissing: true)
            GoogleDriveTokenConfigStore.delete()
            try DropboxTokenStore.deleteRefreshToken(ignoreMissing: true)
            try TinyURLTokenStore.deleteAPIToken(ignoreMissing: true)
            googleRefreshToken = ""
            dropboxRefreshToken = ""
            tinyURLAPIToken = ""
            statusMessage = "Cleared Share+Link tokens from ~/.mimi and Keychain mirrors."
        } catch {
            statusMessage = "Failed to clear tokens: \(error.localizedDescription)"
        }
    }

    // MARK: - Reveal Mimi Directory

    private func revealMimiDirectory() {
        let directory = CloudLinkCredentialsStore.storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}

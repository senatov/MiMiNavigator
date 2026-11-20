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
    @State private var r2AccountID = ""
    @State private var r2Bucket = ""
    @State private var r2PublicURL = ""
    @State private var r2AccessKeyID = ""
    @State private var r2SecretAccessKey = ""
    @State private var statusMessage = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Google client secret:", help: "Desktop OAuth client secret stored in ~/.mimi/google_drive_oauth.json", labelWidth: 170) {
                        CloudCredentialField("client_secret", text: $googleClientSecret)
                    }
                    Divider()
                    SettingsRow(label: "Google refresh token:", help: "Google Drive refresh token stored in ~/.mimi/cloud_link_credentials.json", labelWidth: 170) {
                        CloudCredentialField("refresh_token", text: $googleRefreshToken)
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Dropbox refresh token:", help: "Dropbox OAuth refresh token stored in ~/.mimi/cloud_link_credentials.json", labelWidth: 170) {
                        CloudCredentialField("refresh_token", text: $dropboxRefreshToken)
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "TinyURL API token:", help: "TinyURL API token stored in ~/.mimi/cloud_link_credentials.json. Leave empty to keep original provider links.", labelWidth: 170) {
                        CloudCredentialField("api-token", text: $tinyURLAPIToken)
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "R2 account ID:", help: "Cloudflare Account ID from R2 Overview", labelWidth: 170) {
                        TextField("32-character account ID", text: $r2AccountID).textFieldStyle(.roundedBorder).frame(width: 340)
                    }
                    SettingsRow(label: "R2 bucket:", help: "Public R2 bucket name", labelWidth: 170) {
                        TextField("bucket name", text: $r2Bucket).textFieldStyle(.roundedBorder).frame(width: 340)
                    }
                    SettingsRow(label: "R2 public URL:", help: "HTTPS custom domain or public r2.dev bucket URL", labelWidth: 170) {
                        TextField("https://media.example.com", text: $r2PublicURL).textFieldStyle(.roundedBorder).frame(width: 340)
                    }
                    SettingsRow(label: "R2 access key ID:", help: "R2 S3 API Access Key ID", labelWidth: 170) {
                        CloudCredentialField("Access Key ID", text: $r2AccessKeyID)
                    }
                    SettingsRow(label: "R2 secret access key:", help: "R2 S3 API Secret Access Key", labelWidth: 170) {
                        CloudCredentialField("Secret Access Key", text: $r2SecretAccessKey)
                    }
                }
            }
            HStack(spacing: 10) {
                DownToolbarButtonView(title: "Save", systemImage: "checkmark", iconTint: .green) { saveSettings() }
                    .keyboardShortcut(.defaultAction)
                DownToolbarButtonView(title: "Reload", systemImage: "arrow.clockwise", iconTint: .blue) { loadSettings() }
                DownToolbarButtonView(title: "Clear tokens", systemImage: "trash", iconTint: .red) { clearTokens() }
                Spacer()
                DownToolbarButtonView(title: "Reveal ~/.mimi", systemImage: "folder", iconTint: .blue) { revealMimiDirectory() }
            }
            statusRow
            setupHelp
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Setup Help

    private var setupHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Credential setup")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("Google Drive requires Desktop OAuth credentials and a refresh token. Dropbox requires a refresh token. Cloudflare R2 requires a public bucket and bucket-scoped Object Read & Write S3 keys. R2 uploads media and copies its direct public URL. TinyURL is optional for Google Drive and Dropbox.")
                .font(.system(size: 11))
                .foregroundStyle(SettingsVisualStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                DownToolbarButtonView(title: "Google OAuth Setup", systemImage: "arrow.up.right.square", iconTint: .blue) { openSetupPage(.googleDrive) }
                DownToolbarButtonView(title: "Dropbox App Console", systemImage: "arrow.up.right.square", iconTint: .blue) { openSetupPage(.dropbox) }
                DownToolbarButtonView(title: "TinyURL API", systemImage: "arrow.up.right.square", iconTint: .blue) { openTinyURLSetupPage() }
                DownToolbarButtonView(title: "Cloudflare R2", systemImage: "arrow.up.right.square", iconTint: .blue) { openSetupPage(.cloudflareR2) }
            }
        }
        .padding(12)
        .background(SettingsVisualStyle.cardTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: statusMessage.hasPrefix("Saved") ? "checkmark.circle" : "info.circle")
                .foregroundStyle(SettingsVisualStyle.secondaryText)
                .font(.system(size: 11))
            Text(statusMessage.isEmpty ? "Credentials are read from ~/.mimi before Keychain." : statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(SettingsVisualStyle.secondaryText)
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
            r2AccountID = credentials.r2AccountID ?? ""
            r2Bucket = credentials.r2Bucket ?? ""
            r2PublicURL = credentials.r2PublicURL ?? ""
            r2AccessKeyID = credentials.r2AccessKeyID ?? ""
            r2SecretAccessKey = credentials.r2SecretAccessKey ?? ""
            statusMessage = "Loaded local credentials from \(CloudLinkCredentialsStore.path)."
        } catch {
            statusMessage = "Failed to load local credentials: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Settings

    private func saveSettings() {
        do {
            try GoogleDriveCredentialBootstrap.saveLocalClientSecret(googleClientSecret)
            var credentials = try CloudLinkCredentialsStore.load()
            credentials.googleDriveRefreshToken = googleRefreshToken
            credentials.dropboxRefreshToken = dropboxRefreshToken
            credentials.tinyURLAPIToken = tinyURLAPIToken
            credentials.r2AccountID = r2AccountID
            credentials.r2Bucket = r2Bucket
            credentials.r2PublicURL = r2PublicURL
            credentials.r2AccessKeyID = r2AccessKeyID
            credentials.r2SecretAccessKey = r2SecretAccessKey
            try CloudLinkCredentialsStore.save(credentials)
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
            try CloudLinkCredentialsStore.setToken(nil, for: .r2AccessKeyID)
            try CloudLinkCredentialsStore.setToken(nil, for: .r2SecretAccessKey)
            googleRefreshToken = ""
            dropboxRefreshToken = ""
            tinyURLAPIToken = ""
            r2AccessKeyID = ""
            r2SecretAccessKey = ""
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

    // MARK: - Open Setup Page

    private func openSetupPage(_ provider: CloudProvider) {
        guard let url = CloudLinkSetupCoordinator.setupURL(for: provider) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Open TinyURL Setup Page

    private func openTinyURLSetupPage() {
        NSWorkspace.shared.open(CloudLinkSetupCoordinator.tinyURLSetupURL)
    }
}

// MARK: - CloudCredentialField
private struct CloudCredentialField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    var body: some View {
        HStack(spacing: 5) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(isVisible ? "Hide value" : "Show value")
            .accessibilityLabel(isVisible ? "Hide value" : "Show value")
        }
        .frame(width: 340)
    }
}

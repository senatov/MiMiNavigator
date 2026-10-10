// SettingsGitClientsPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Preferred Git client and installation controls.

import AppKit
import SwiftUI

// MARK: - Git Clients Settings
struct SettingsGitClientsPane: View {
    @State private var registry = GitClientRegistry.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default Git client")
                        .font(.system(size: 13, weight: .semibold))
                    Picker("Open repository with", selection: Binding(
                        get: { registry.preferredClient },
                        set: { registry.setPreferred($0) }
                    )) {
                        ForEach(GitClient.allCases) { client in
                            Text(registry.isInstalled(client) ? client.name : "\(client.name) (not installed)")
                                .tag(client)
                                .disabled(!registry.isInstalled(client))
                        }
                    }
                    .frame(maxWidth: 350)
                    Text("Click a Git mark in a file row or the panel status bar to open this client. Right-click for another installed client.")
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                }
            }
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Git clients")
                        .font(.system(size: 13, weight: .semibold))
                    ForEach(GitClient.allCases) { client in
                        HStack(spacing: 10) {
                            Image(systemName: registry.isInstalled(client) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(registry.isInstalled(client) ? .green : .secondary)
                            Text(client.name)
                                .font(.system(size: 12))
                            Spacer()
                            if client != .terminal && !registry.isInstalled(client) {
                                Button("Install…") { registry.install(client) }
                                    .buttonStyle(ThemedButtonStyle())
                                    .controlSize(.small)
                            }
                        }
                        .frame(minHeight: 30)
                        if client != GitClient.allCases.last { Divider() }
                    }
                    Text("Install opens Homebrew in Terminal. If Homebrew is unavailable, the client website opens instead.")
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                }
            }
        }
        .onAppear { registry.refreshAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            registry.refreshAvailability()
        }
    }
}

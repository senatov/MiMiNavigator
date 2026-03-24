// SettingsNetworkPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   Network  (stub — Network pane in ConnectToServer)
// MARK: - ════════════════════════════════════════════

struct SettingsNetworkPane: View {

    @State private var prefs = UserPreferences.shared

    private func prefBinding<T>(_ keyPath: WritableKeyPath<PreferencesSnapshot, T>) -> Binding<T> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] },
            set: { prefs.snapshot[keyPath: keyPath] = $0; prefs.save() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Timeout:", help: "Connection timeout in seconds") {
                        HStack(spacing: 10) {
                            Slider(value: prefBinding(\.networkTimeoutSec), in: 5...60, step: 5)
                                .frame(width: 140)
                            Text("\(Int(prefs.snapshot.networkTimeoutSec)) s")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Retry attempts:", help: "How many times to retry on connection drop") {
                        HStack(spacing: 10) {
                            Slider(value: prefBinding(\.networkRetryCount), in: 0...10, step: 1)
                                .frame(width: 140)
                            Text("\(Int(prefs.snapshot.networkRetryCount))×")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Auto-reconnect:", help: "Try to restore dropped connections automatically") {
                        Toggle("Reconnect automatically", isOn: prefBinding(\.networkAutoReconnect))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Passwords:", help: "Save server passwords in macOS Keychain") {
                        Toggle("Save passwords in Keychain", isOn: prefBinding(\.networkSavePasswords))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Sidebar:", help: "Show connected servers in the Favorites sidebar") {
                        Toggle("Show connected servers in sidebar", isOn: prefBinding(\.networkShowInSidebar))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // Info row
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                Text("Detailed server configuration is available in Connect to Server (⌘K)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}


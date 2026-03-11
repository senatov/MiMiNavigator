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
    @AppStorage("settings.network.timeoutSec")       private var timeoutSec: Double = 15
    @AppStorage("settings.network.retryCount")       private var retryCount: Double = 3
    @AppStorage("settings.network.savePasswords")    private var savePasswords: Bool = true
    @AppStorage("settings.network.showInSidebar")    private var showInSidebar: Bool = true
    @AppStorage("settings.network.autoReconnect")    private var autoReconnect: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Timeout:", help: "Connection timeout in seconds") {
                        HStack(spacing: 10) {
                            Slider(value: $timeoutSec, in: 5...60, step: 5)
                                .frame(width: 140)
                            Text("\(Int(timeoutSec)) s")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Retry attempts:", help: "How many times to retry on connection drop") {
                        HStack(spacing: 10) {
                            Slider(value: $retryCount, in: 0...10, step: 1)
                                .frame(width: 140)
                            Text("\(Int(retryCount))×")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Auto-reconnect:", help: "Try to restore dropped connections automatically") {
                        Toggle("Reconnect automatically", isOn: $autoReconnect)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Passwords:", help: "Save server passwords in macOS Keychain") {
                        Toggle("Save passwords in Keychain", isOn: $savePasswords)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Sidebar:", help: "Show connected servers in the Favorites sidebar") {
                        Toggle("Show connected servers in sidebar", isOn: $showInSidebar)
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


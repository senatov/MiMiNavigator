// SettingsTabsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   Tabs
// MARK: - ════════════════════════════════════════════

struct SettingsTabsPane: View {

    @AppStorage("settings.tabs.restoreOnLaunch")    private var restoreOnLaunch: Bool = true
    @AppStorage("settings.tabs.openFolderInNewTab") private var openFolderInNewTab: Bool = false
    @AppStorage("settings.tabs.closeLastKeepsPanel")private var closeLastKeepsPanel: Bool = true
    @AppStorage("settings.tabs.position")           private var position: String = "top"
    @AppStorage("settings.tabs.showCloseButton")    private var showCloseButton: Bool = true
    @AppStorage("settings.tabs.maxTabs")            private var maxTabs: Double = 32
    @AppStorage("settings.tabs.sortByName")         private var sortByName: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Behaviour ────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Restore tabs:", help: "Reopen tabs from last session on app launch") {
                        Toggle("Restore tabs on launch", isOn: $restoreOnLaunch)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "New tab on Enter:", help: "Open folder in a new tab instead of navigating in-place") {
                        Toggle("Open folders in new tab (double-click)", isOn: $openFolderInNewTab)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Close last tab:", help: "Keep panel visible when closing the last remaining tab") {
                        Picker("", selection: $closeLastKeepsPanel) {
                            Text("Keep panel open (home dir)").tag(true)
                            Text("Close panel").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
            }

            // ── Appearance ───────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Tab bar position:", help: "Where the tab bar is shown relative to the file list") {
                        Picker("", selection: $position) {
                            Text("Top").tag("top")
                            Text("Bottom").tag("bottom")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                    }
                    Divider()
                    SettingsRow(label: "Close button:", help: "Show × button on each tab") {
                        Toggle("Show close button on tabs", isOn: $showCloseButton)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Limits ───────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Max open tabs:", help: "Maximum number of tabs per panel (2–64)") {
                        HStack(spacing: 10) {
                            Slider(value: $maxTabs, in: 2...64, step: 1)
                                .frame(width: 140)
                            Text("\(Int(maxTabs))").monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                        }
                    }
                }
            }
        }
    }
}


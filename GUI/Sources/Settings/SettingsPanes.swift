// SettingsPanes.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: All settings panes — General (real), rest are stubs for next iterations.

import SwiftUI

// MARK: - Shared style helpers

private struct SettingsRow<Content: View>: View {
    let label: String
    let help: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 200, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 16)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

private struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

private struct StubPane: View {
    let section: SettingsSection

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: section.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("\(section.rawValue) settings coming soon")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   General
// MARK: - ════════════════════════════════════════════

struct SettingsGeneralPane: View {

    @AppStorage("settings.appearance")       private var appearance: String = "system"
    @AppStorage("settings.panelFontSize")    private var panelFontSize: Double = 13
    @AppStorage("settings.iconSize")         private var iconSize: String = "medium"
    @AppStorage("settings.showHiddenFiles")  private var showHiddenFiles: Bool = false
    @AppStorage("settings.showExtensions")   private var showExtensions: Bool = true
    @AppStorage("settings.startupPath")      private var startupPath: String = "home"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Appearance ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Appearance:", help: "Override system light/dark mode") {
                        Picker("", selection: $appearance) {
                            Text("Follow System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                }
            }

            // ── Text & Icons ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Panel font size:", help: "Font size used in file lists") {
                        HStack(spacing: 10) {
                            Slider(value: $panelFontSize, in: 10...18, step: 1)
                                .frame(width: 140)
                            Text("\(Int(panelFontSize)) pt")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 36)
                        }
                    }

                    Divider().padding(.leading, 0)

                    SettingsRow(label: "Icon size:", help: "Size of file/folder icons in panels") {
                        Picker("", selection: $iconSize) {
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }

            // ── Files ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Hidden files:", help: "Show files and folders starting with dot (.)") {
                        Toggle("Show hidden files (.dotfiles)", isOn: $showHiddenFiles)
                            .toggleStyle(.checkbox)
                    }

                    Divider()

                    SettingsRow(label: "Extensions:", help: "Always show file extensions in file names") {
                        Toggle("Always show file extensions", isOn: $showExtensions)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Startup ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Start in:", help: "Which directory to open at app launch") {
                        Picker("", selection: $startupPath) {
                            Text("Home folder (~)").tag("home")
                            Text("Last visited location").tag("last")
                            Text("Desktop").tag("desktop")
                            Text("Downloads").tag("downloads")
                        }
                        .frame(maxWidth: 220)
                        .labelsHidden()
                    }
                }
            }
        }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Panels  (stub — Stage 2)
// MARK: - ════════════════════════════════════════════

struct SettingsPanelsPane: View {
    var body: some View { StubPane(section: .panels) }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Tabs  (stub — Stage 3)
// MARK: - ════════════════════════════════════════════

struct SettingsTabsPane: View {
    var body: some View { StubPane(section: .tabs) }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Archives  (stub — Stage 4)
// MARK: - ════════════════════════════════════════════

struct SettingsArchivesPane: View {
    var body: some View { StubPane(section: .archives) }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Network  (stub — Stage 5)
// MARK: - ════════════════════════════════════════════

struct SettingsNetworkPane: View {
    var body: some View { StubPane(section: .network) }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Diff Tool  (stub — Stage 6)
// MARK: - ════════════════════════════════════════════

struct SettingsDiffToolPane: View {
    var body: some View { StubPane(section: .diffTool) }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Hotkeys  — uses existing HotKeySettingsView
// MARK: - ════════════════════════════════════════════

struct SettingsHotkeysPane: View {
    var body: some View {
        HotKeySettingsView()
            .frame(minHeight: 380)
    }
}

// NOTE: SettingsColorsPane → SettingsColorsPane.swift
// NOTE: SettingsPermissionsPane → SettingsPermissionsPane.swift

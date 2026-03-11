// SettingsPanelsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   Panels
// MARK: - ════════════════════════════════════════════

struct SettingsPanelsPane: View {

    // Sync these keys with UserPreferences / AppState where wired
    @AppStorage("settings.panels.showHiddenFiles")   private var showHiddenFiles: Bool = false
    @AppStorage("settings.panels.showExtensions")    private var showExtensions: Bool = true
    @AppStorage("settings.panels.showIcons")         private var showIcons: Bool = true
    @AppStorage("settings.panels.calculateSizes")    private var calculateSizes: Bool = false
    @AppStorage("settings.panels.highlightBorder")   private var highlightBorder: Bool = true
    @AppStorage("settings.panels.defaultSort")       private var defaultSort: String = "name"
    @AppStorage("settings.panels.sortAscending")     private var sortAscending: Bool = true
    @AppStorage("settings.panels.dateFormat")        private var dateFormat: String = "short"
    @AppStorage("settings.panels.showSizeInKB")      private var showSizeInKB: Bool = false
    @AppStorage("settings.panels.openOnSingleClick") private var openOnSingleClick: Bool = false
    @AppStorage("settings.panels.rowDensity")        private var rowDensity: String = "normal"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Row density ──────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Row height:", help: "Height of each row in the file list. Compact = dense list, Spacious = more breathing room.") {
                        Picker("", selection: $rowDensity) {
                            ForEach(FilePanelStyle.RowDensity.allCases, id: \.rawValue) { d in
                                Text(d.label).tag(d.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                        .onChange(of: rowDensity) { _, _ in
                            // FilePanelStyle.rowHeight reads UserDefaults directly — no extra action needed
                            // Panels will pick up new height on next layout pass
                        }
                    }
                }
            }
            // ── Files display ───────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Hidden files:", help: "Show files and folders starting with dot (.)") {
                        Toggle("Show hidden files (.dotfiles)", isOn: $showHiddenFiles)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Extensions:", help: "Always show file extensions") {
                        Toggle("Always show file extensions", isOn: $showExtensions)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Icons:", help: "Show file and folder icons in list view") {
                        Toggle("Show icons in file list", isOn: $showIcons)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Folder sizes:", help: "Calculate and show folder sizes (slower, uses du)") {
                        Toggle("Calculate folder sizes", isOn: $calculateSizes)
                            .toggleStyle(.checkbox)
                        if calculateSizes {
                            Text("May slow down large directories")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .padding(.leading, 8)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Active panel:", help: "Highlight border of the focused panel") {
                        Toggle("Highlight active panel border", isOn: $highlightBorder)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Sorting ──────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Default sort:", help: "Sort files by this column when opening a folder") {
                        HStack(spacing: 12) {
                            Picker("", selection: $defaultSort) {
                                Text("Name").tag("name")
                                Text("Date").tag("date")
                                Text("Size").tag("size")
                                Text("Type").tag("type")
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            Picker("", selection: $sortAscending) {
                                Text("↑ Ascending").tag(true)
                                Text("↓ Descending").tag(false)
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }
                }
            }

            // ── Date & Size format ───────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Date format:", help: "How modification date is shown in the file list") {
                        Picker("", selection: $dateFormat) {
                            Text("Short  (14.02.26)").tag("short")
                            Text("Medium (Feb 14, 2026)").tag("medium")
                            Text("Relative (2 days ago)").tag("relative")
                            Text("ISO-8601").tag("iso")
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    Divider()
                    SettingsRow(label: "Size display:", help: "Show file sizes in KB instead of auto-scaling") {
                        Toggle("Always show size in KB", isOn: $showSizeInKB)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Navigation ───────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Open on:", help: "Open files and folders with single or double click") {
                        Picker("", selection: $openOnSingleClick) {
                            Text("Double click").tag(false)
                            Text("Single click").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }
        }
    }
}


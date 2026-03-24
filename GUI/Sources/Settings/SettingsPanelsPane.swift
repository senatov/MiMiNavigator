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

    @State private var prefs = UserPreferences.shared

    private func prefBinding<T>(_ keyPath: WritableKeyPath<PreferencesSnapshot, T>) -> Binding<T> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] },
            set: { prefs.snapshot[keyPath: keyPath] = $0; prefs.save() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Row density ──────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Row height:", help: "Height of each row in the file list. Compact = dense list, Spacious = more breathing room.") {
                        Picker("", selection: prefBinding(\.rowDensity)) {
                            ForEach(FilePanelStyle.RowDensity.allCases, id: \.rawValue) { d in
                                Text(d.label).tag(d.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                        .onChange(of: prefs.snapshot.rowDensity) { _, _ in
                            // panels pick up new height on next layout pass
                        }
                    }
                }
            }
            // ── Files display ───────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Hidden files:", help: "Show files and folders starting with dot (.)") {
                        Toggle("Show hidden files (.dotfiles)", isOn: prefBinding(\.showHiddenFiles))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Extensions:", help: "Always show file extensions") {
                        Toggle("Always show file extensions", isOn: prefBinding(\.showExtensions))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Icons:", help: "Show file and folder icons in list view") {
                        Toggle("Show icons in file list", isOn: prefBinding(\.showIcons))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Folder sizes:", help: "Calculate and show folder sizes (slower, uses du)") {
                        Toggle("Calculate folder sizes", isOn: prefBinding(\.calculateSizes))
                            .toggleStyle(.checkbox)
                        if prefs.snapshot.calculateSizes {
                            Text("May slow down large directories")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .padding(.leading, 8)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Active panel:", help: "Highlight border of the focused panel") {
                        Toggle("Highlight active panel border", isOn: prefBinding(\.highlightBorder))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Sorting ──────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Default sort:", help: "Sort files by this column when opening a folder") {
                        HStack(spacing: 12) {
                            Picker("", selection: prefBinding(\.defaultSort)) {
                                Text("Name").tag("name")
                                Text("Date").tag("date")
                                Text("Size").tag("size")
                                Text("Type").tag("type")
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            Picker("", selection: prefBinding(\.sortAscending)) {
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
                        Picker("", selection: prefBinding(\.dateFormat)) {
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
                        Toggle("Always show size in KB", isOn: prefBinding(\.showSizeInKB))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Navigation ───────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Open on:", help: "Open files and folders with single or double click") {
                        Picker("", selection: prefBinding(\.openOnSingleClick)) {
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


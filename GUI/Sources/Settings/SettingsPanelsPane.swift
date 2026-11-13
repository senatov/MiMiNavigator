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
            set: {
                prefs.snapshot[keyPath: keyPath] = $0
                AppStateProvider.shared?.applyPreferencesFromSnapshot()
            }
        )
    }

    private var showHiddenFilesBinding: Binding<Bool> {
        Binding(
            get: { prefs.snapshot.showHiddenFiles },
            set: { AppStateProvider.shared?.setShowHiddenFiles($0) }
        )
    }

    private var excludeDirectoriesFromSortingBinding: Binding<Bool> {
        Binding(
            get: { prefs.snapshot.excludeDirectoriesFromSorting ?? true },
            set: {
                prefs.snapshot.excludeDirectoriesFromSorting = $0
                AppStateProvider.shared?.applyPreferencesFromSnapshot()
            }
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
                        Toggle("Show hidden files (.dotfiles)", isOn: showHiddenFilesBinding)
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
                    SettingsRow(label: "Files:", help: "Choose how files are sorted. This does not affect folders when the separate folder rule is enabled.") {
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
                    Divider()
                    SettingsRow(label: "Folders:", help: "Keep folders above files and always sort their names alphabetically from A to Z.") {
                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Keep folders first, sorted A → Z", isOn: excludeDirectoriesFromSortingBinding)
                                .toggleStyle(.checkbox)
                            Text(prefs.snapshot.excludeDirectoriesFromSorting ?? true
                                ? "File sorting applies only to files."
                                : "Folders follow the selected file sort and direction.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // ── Date & Size format ───────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Date format:", help: "How dates are shown in file list columns") {
                        Picker("", selection: prefBinding(\.dateFormat)) {
                            Text("System (Finder)").tag("system")
                            Text("Short (14.02.26 09:30)").tag("short")
                            Text("Full year (14.02.2026 09:30)").tag("long")
                            Text("Medium (Feb 14, 2026)").tag("medium")
                            Text("Relative (Today, 09:30)").tag("relative")
                            Text("ISO (2026-02-14 09:30)").tag("iso")
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                    Divider()
                    SettingsRow(label: "Size format:", help: "Choose the base and units used in file list columns") {
                        Picker("", selection: Binding(
                            get: { prefs.snapshot.sizeFormat ?? "system" },
                            set: { prefs.snapshot.sizeFormat = $0 }
                        )) {
                            Text("System (Finder)").tag("system")
                            Text("Decimal (1000: KB, MB)").tag("decimal")
                            Text("Binary (1024: KiB, MiB)").tag("binary")
                            Text("Exact bytes").tag("bytes")
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                    Divider()
                    SettingsRow(label: "Size display:", help: "Override the selected size format with whole KB") {
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

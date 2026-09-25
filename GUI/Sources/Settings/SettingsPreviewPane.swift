// SettingsPreviewPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings for remembered per-extension embedded Preview modes.

import SwiftUI

// MARK: - Settings Preview Pane
struct SettingsPreviewPane: View {
    @State private var store = PreviewDisplayModeStore.shared
    @State private var newExtension = ""
    @State private var newMode: PreviewDisplayMode = .quickLook

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Automatic preview", systemImage: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                    Text("Known text, image, PDF, media, document, archive, and executable types are handled automatically. MiMiNavigator asks once when it encounters an unknown extension.")
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Add file type:", help: "Create a persistent preview rule for a filename extension") {
                        HStack(spacing: 8) {
                            DialogTextField("extension", text: $newExtension)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            modePicker(selection: $newMode)
                            Button("Add") { addRule() }
                                .disabled(normalizedNewExtension.isEmpty)
                        }
                    }
                    if !store.rules.isEmpty { Divider() }
                    ForEach(sortedRules, id: \.key) { entry in
                        SettingsRow(label: ".\(entry.key):", help: "Remembered Preview mode for .\(entry.key) files") {
                            HStack(spacing: 8) {
                                modePicker(selection: Binding(
                                    get: { store.rules[entry.key] ?? entry.value },
                                    set: { store.set($0, forExtension: entry.key) }
                                ))
                                Button {
                                    store.removeRule(forExtension: entry.key)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove rule and use automatic detection")
                            }
                        }
                        if entry.key != sortedRules.last?.key { Divider() }
                    }
                }
            }

            if !store.rules.isEmpty {
                Button("Remove All Remembered Rules") { store.removeAllRules() }
                    .foregroundStyle(.red)
            }
        }
    }

    private var sortedRules: [(key: String, value: PreviewDisplayMode)] {
        store.rules.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    private var normalizedNewExtension: String {
        let clean = newExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.hasPrefix(".") ? String(clean.dropFirst()) : clean
    }

    private func addRule() {
        guard !normalizedNewExtension.isEmpty else { return }
        store.set(newMode, forExtension: normalizedNewExtension)
        newExtension = ""
    }

    private func modePicker(selection: Binding<PreviewDisplayMode>) -> some View {
        Picker("", selection: selection) {
            ForEach(PreviewDisplayMode.allCases) { mode in
                Label(mode.title, systemImage: mode.symbol).tag(mode)
            }
        }
        .labelsHidden()
        .frame(width: 150)
    }
}

// TableHeaderView+ContextMenu.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column visibility, presets, auto-fit, and reset menu for table headers.

import SwiftUI

// MARK: - Column Context Menu
extension TableHeaderView {
    @ViewBuilder
    var columnToggleMenu: some View {
        Picker("Column Preset", selection: Binding<ColumnLayoutPreset?>(
            get: { ColumnLayoutPreset.allCases.first { layout.visibleColumns.map(\.id) == $0.columns } },
            set: { if let preset = $0 { applyColumnPreset(preset) } }
        )) {
            ForEach(ColumnLayoutPreset.allCases) { preset in
                Label(preset.rawValue, systemImage: preset.systemImage).tag(Optional(preset))
            }
        }
        Divider()
        ForEach(layout.columns) { spec in
            if !spec.id.isRequired {
                Toggle(spec.id.title, isOn: Binding(
                    get: { layout.columns.first(where: { $0.id == spec.id })?.isVisible ?? false },
                    set: { newValue in
                        let current = layout.columns.first(where: { $0.id == spec.id })?.isVisible ?? false
                        if newValue != current {
                            layout.toggle(spec.id)
                            if newValue { autoFitAllColumns() }
                            if newValue, spec.id.needsFinderMetadata {
                                Task { await appState.refreshFiles(for: panelSide, force: true) }
                            }
                        }
                    }
                ))
            }
        }
        Divider()
        Button {
            autoFitAllColumns()
        } label: {
            Label("Auto Fit All Columns", systemImage: "arrow.left.and.right.text.vertical")
        }
        Toggle("Auto Fit After Navigation", isOn: Binding(
            get: { UserPreferences.shared.snapshot.autoFitColumnsOnNavigate },
            set: { newValue in
                UserPreferences.shared.snapshot.autoFitColumnsOnNavigate = newValue
                UserPreferences.shared.save()
                guard newValue else { return }
                guard !layout.isColumnReorderActive else { return }
                let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
                ColumnAutoFitter.autoFitAll(layout: layout, files: files)
            }
        ))
        Divider()
        Button("Reset Column Layout") { layout.restoreDefaults() }
    }

    // MARK: - Preset
    private func applyColumnPreset(_ preset: ColumnLayoutPreset) {
        layout.applyPreset(preset)
        autoFitAllColumns()
        if layout.visibleColumns.contains(where: { $0.id.needsFinderMetadata }) {
            Task { await appState.refreshFiles(for: panelSide, force: true) }
        }
    }

    // MARK: - Auto Fit
    private func autoFitAllColumns() {
        guard !layout.isColumnReorderActive else { return }
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        layout.saveWidths()
    }
}

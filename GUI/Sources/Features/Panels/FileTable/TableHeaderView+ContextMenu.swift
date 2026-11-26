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
        Picker(selection: Binding<ColumnLayoutPreset?>(
            get: { ColumnLayoutPreset.allCases.first { layout.configuredVisibleColumns.map(\.id) == $0.columns } },
            set: { if let preset = $0 { applyColumnPreset(preset) } }
        )) {
            ForEach(ColumnLayoutPreset.allCases) { preset in
                ContextMenuLabel(preset.rawValue, systemImage: preset.systemImage).tag(Optional(preset))
            }
        } label: {
            ContextMenuLabel("Column Preset", systemImage: "tablecells")
        }
        Divider()
        ForEach(layout.columns) { spec in
            if !spec.id.isRequired {
                Toggle(isOn: Binding(
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
                )) {
                    ContextMenuLabel(spec.id.title, systemImage: "rectangle.split.3x1")
                }
            }
        }
        Divider()
        Toggle(isOn: Binding(
            get: { manualAutoFit?.fitted == layout.makeSnapshot() },
            set: setManualAutoFit
        )) {
            ContextMenuLabel("Auto Fit All Columns", systemImage: "arrow.left.and.right.text.vertical")
        }
        .disabled(layout.isColumnReorderActive || layout.containerWidth <= 0 || appState.displayedFiles(for: panelSide).isEmpty)
        Toggle(isOn: Binding(
            get: { UserPreferences.shared.snapshot.autoFitColumnsOnNavigate },
            set: { newValue in
                UserPreferences.shared.snapshot.autoFitColumnsOnNavigate = newValue
                UserPreferences.shared.save()
                guard newValue else { return }
                guard !layout.isColumnReorderActive else { return }
                let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
                ColumnAutoFitter.autoFitAll(layout: layout, files: files)
            }
        )) {
            ContextMenuLabel("Auto Fit After Navigation", systemImage: "arrow.left.and.right.text.vertical")
        }
        Divider()
        Button { layout.restoreDefaults() } label: { ContextMenuLabel("Reset Column Layout", systemImage: "arrow.counterclockwise") }
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
    private func setManualAutoFit(_ enabled: Bool) {
        guard !layout.isColumnReorderActive else { return }
        let current = layout.makeSnapshot()
        if enabled {
            guard layout.containerWidth > 0, !appState.displayedFiles(for: panelSide).isEmpty else { return }
            autoFitAllColumns()
            manualAutoFit = (before: current, fitted: layout.makeSnapshot())
        } else {
            if let manualAutoFit, manualAutoFit.fitted == current {
                layout.applySnapshot(manualAutoFit.before)
                layout.saveWidths()
            }
            manualAutoFit = nil
        }
    }

    // MARK: - Fit and Save
    private func autoFitAllColumns() {
        guard !layout.isColumnReorderActive else { return }
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        layout.saveWidths()
    }
}

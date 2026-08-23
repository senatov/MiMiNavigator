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
        Menu("Column Preset") {
            ForEach(ColumnLayoutPreset.allCases) { preset in
                Button {
                    applyColumnPreset(preset)
                } label: {
                    Label(preset.rawValue, systemImage: preset.systemImage)
                }
            }
        }
        Divider()
        ForEach(layout.columns) { spec in
            if !spec.id.isRequired {
                Button {
                    layout.toggle(spec.id)
                } label: {
                    Label(spec.id.title, systemImage: spec.isVisible ? "checkmark" : "")
                }
            }
        }
        Divider()
        Button {
            autoFitAllColumns()
        } label: {
            Label("Auto Fit All Columns", systemImage: "arrow.left.and.right.text.vertical")
        }
        let autoFitOn = UserPreferences.shared.snapshot.autoFitColumnsOnNavigate
        Button {
            let newValue = !autoFitOn
            UserPreferences.shared.snapshot.autoFitColumnsOnNavigate = newValue
            UserPreferences.shared.save()
            if newValue {
                guard !layout.isColumnReorderActive else { return }
                let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
                ColumnAutoFitter.autoFitAll(layout: layout, files: files)
            }
        } label: {
            Label("Auto Fit After Navigation", systemImage: autoFitOn ? "checkmark" : "")
        }
        Divider()
        Button("Reset Column Layout") { layout.restoreDefaults() }
    }

    // MARK: - Preset
    private func applyColumnPreset(_ preset: ColumnLayoutPreset) {
        layout.applyPreset(preset)
        autoFitAllColumns()
    }

    // MARK: - Auto Fit
    private func autoFitAllColumns() {
        guard !layout.isColumnReorderActive else { return }
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        ColumnAutoFitter.autoFitAll(layout: layout, files: files)
        layout.saveWidths()
    }
}

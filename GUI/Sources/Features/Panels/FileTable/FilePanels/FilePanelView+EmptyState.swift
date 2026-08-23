// FilePanelView+EmptyState.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Informative empty and filtered-empty states for file panels.

import SwiftUI

// MARK: - File Panel Empty State
extension FilePanelView {
    @ViewBuilder
    var panelEmptyStateOverlay: some View {
        if files.isEmpty && !appState.isLoading(viewModel.panelSide) {
            let query = viewModel.panelSide == .left ? appState.leftFilterQuery : appState.rightFilterQuery
            PanelEmptyStateView(
                isFiltered: !query.isEmpty,
                onClearFilter: {
                    if viewModel.panelSide == .left {
                        appState.leftFilterQuery = ""
                    } else {
                        appState.rightFilterQuery = ""
                    }
                }
            )
            .padding(.bottom, 38)
        }
    }
}

// MARK: - Panel Empty State View
private struct PanelEmptyStateView: View {
    let isFiltered: Bool
    let onClearFilter: () -> Void

    var body: some View {
        StatusCard(
            title: isFiltered ? "No matching items" : "This folder is empty",
            message: isFiltered ? "Change or clear the local folder filter." : "Drop files here or use New Folder to get started.",
            systemImage: isFiltered ? "line.3.horizontal.decrease.circle" : "folder",
            kind: isFiltered ? .warning : .empty
        ) {
            if isFiltered {
                Button("Clear Filter", action: onClearFilter)
                    .buttonStyle(ThemedButtonStyle())
                    .controlSize(.small)
            }
        }
    }
}

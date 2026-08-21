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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.72), Color.accentColor.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "folder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(isFiltered ? Color.orange : Color.accentColor)
            }
            .frame(width: 48, height: 48)
            .overlay { Circle().strokeBorder(Color.black.opacity(0.10), lineWidth: 0.6) }
            .shadow(color: Color.black.opacity(0.10), radius: 2, y: 1)
            Text(isFiltered ? "No matching items" : "This folder is empty")
                .font(.system(size: 13, weight: .semibold))
            Text(isFiltered ? "Change or clear the local folder filter." : "Drop files here or use New Folder to get started.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if isFiltered {
                Button("Clear Filter", action: onClearFilter)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.76))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.65)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
    }
}

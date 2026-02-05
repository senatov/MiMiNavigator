// SelectionStatusBar.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Status bar showing marked files count and total size (Total Commander style)

import SwiftUI

// MARK: - Selection Status Bar
/// Shows information about marked files at the bottom of file panel
struct SelectionStatusBar: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    private var markedCount: Int {
        appState.markedCount(for: panelSide)
    }

    private var markedSize: Int64 {
        appState.markedTotalSize(for: panelSide)
    }

    private var totalFiles: Int {
        appState.displayedFiles(for: panelSide).count
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: markedSize, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Marked files indicator
            if markedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)

                    Text(L10n.Selection.markedCount(markedCount))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                Text("•")
                    .foregroundStyle(.secondary)

                Text(L10n.Selection.markedSize(formattedSize))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Total files count
            Text("\(totalFiles) items")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .animation(.easeInOut(duration: 0.15), value: markedCount)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        SelectionStatusBar(panelSide: .left)
    }
    .frame(width: 400)
    .environment(AppState())
}

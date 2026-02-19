// SelectionStatusBar.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Status bar showing marked files count, disk space, and inline file filter

import SwiftUI

// MARK: - Selection Status Bar
/// Shows disk space / marked files info + inline filter at the bottom of each panel
struct SelectionStatusBar: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    private var markedCount: Int { appState.markedCount(for: panelSide) }
    private var markedSize: Int64 { appState.markedTotalSize(for: panelSide) }
    private var totalFiles: Int { appState.displayedFiles(for: panelSide).count }
    private var formattedSize: String { ByteCountFormatter.string(fromByteCount: markedSize, countStyle: .file) }
    private var currentPath: String { panelSide == .left ? appState.leftPath : appState.rightPath }

    private var filterQuery: Binding<String> {
        Binding(
            get: { panelSide == .left ? appState.leftFilterQuery : appState.rightFilterQuery },
            set: { val in
                if panelSide == .left { appState.leftFilterQuery = val }
                else { appState.rightFilterQuery = val }
            }
        )
    }

    /// Available disk space for the volume containing the current panel path
    private var availableDiskSpace: String {
        let url = URL(fileURLWithPath: currentPath)
        if let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) {
            if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
                return ByteCountFormatter.string(fromByteCount: important, countStyle: .file)
            }
            if let basic = values.volumeAvailableCapacity, basic > 0 {
                return ByteCountFormatter.string(fromByteCount: Int64(basic), countStyle: .file)
            }
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: currentPath),
           let freeSize = attrs[.systemFreeSize] as? Int64, freeSize > 0 {
            return ByteCountFormatter.string(fromByteCount: freeSize, countStyle: .file)
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left: disk space or marked files
            if markedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)))
                    Text(L10n.Selection.markedCount(markedCount))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)))
                }
                Text("•").foregroundStyle(.secondary)
                Text(L10n.Selection.markedSize(formattedSize))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(availableDiskSpace) free")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Center: filter bar
            PanelFilterBar(query: filterQuery, panelSide: panelSide)
                .frame(minWidth: 140, maxWidth: 220)

            Spacer()

            // Right: total items
            Text("\(totalFiles) items")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .animation(.easeInOut(duration: 0.15), value: markedCount)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        SelectionStatusBar(panelSide: .left)
    }
    .frame(width: 500)
    .environment(AppState())
}

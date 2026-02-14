// SelectionStatusBar.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Status bar showing marked files count and total size (Total Commander style)

import SwiftUI

// MARK: - Selection Status Bar
/// Shows information about marked files and available disk space at the bottom of file panel
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

    private var currentPath: String {
        panelSide == .left ? appState.leftPath : appState.rightPath
    }

    /// Available disk space for the volume containing the current panel path
    private var availableDiskSpace: String {
        let url = URL(fileURLWithPath: currentPath)
        // Try the preferred key first, fall back to basic available capacity
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
        // Last resort: FileManager attributesOfFileSystem
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: currentPath),
           let freeSize = attrs[.systemFreeSize] as? Int64, freeSize > 0 {
            return ByteCountFormatter.string(fromByteCount: freeSize, countStyle: .file)
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left side: disk space or marked files info
            if markedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)))

                    Text(L10n.Selection.markedCount(markedCount))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)))
                }

                Text("•")
                    .foregroundStyle(.secondary)

                Text(L10n.Selection.markedSize(formattedSize))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                // Available disk space
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("\(availableDiskSpace) free")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right side: total items count
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

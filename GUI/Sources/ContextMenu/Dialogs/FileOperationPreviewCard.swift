// FileOperationPreviewCard.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared source, destination, and result preview for file operation dialogs.

import SwiftUI

// MARK: - File Operation Preview Row
struct FileOperationPreviewRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let systemImage: String
}

// MARK: - File Operation Preview Card
struct FileOperationPreviewCard: View {
    let rows: [FileOperationPreviewRow]
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.related) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.related) {
                    Image(systemName: row.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    Text(row.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .leading)
                    Text(row.value)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DesignTokens.Spacing.group)
        .semanticSurface()
        .accessibilityElement(children: .contain)
    }
}

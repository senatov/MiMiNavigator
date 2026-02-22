// BatchProgressDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact progress dialog for batch file operations

import SwiftUI

// MARK: - Batch Progress Dialog
/// Compact progress window showing operation type, current file, progress bar and Stop button
struct BatchProgressDialog: View {
    @Environment(AppState.self) var appState
    let state: BatchOperationState
    let onCancel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: operation title + destination
            VStack(alignment: .leading, spacing: 2) {
                Text(state.operationType.localizedTitle)
                    .font(.system(size: 13, weight: .semibold))
                if let dest = state.destinationURL {
                    Text(dest.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // Current file + counter
            HStack {
                Text(state.currentFileName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(state.processedFiles + 1) / \(state.totalFiles)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar (native macOS style)
            ProgressView(value: state.bytesProgressFraction)
                .progressViewStyle(.linear)

            // Bytes progress text
            if state.totalBytes > 0 {
                Text(state.progressText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Stop button (right-aligned)
            HStack {
                Spacer()
                Button("Stop") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

// BatchProgressDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Progress dialog for batch file operations (Total Commander style)

import SwiftUI

// MARK: - Batch Progress Dialog
/// Shows progress of batch file operations with cancel button
struct BatchProgressDialog: View {
    @Environment(AppState.self) var appState
    let state: BatchOperationState
    let onCancel: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHoveringCancel = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with operation icon
            HStack(spacing: 12) {
                operationIcon
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.operationType.localizedTitle)
                        .font(.system(size: 15, weight: .semibold))
                    
                    if let dest = state.destinationURL {
                        Text(dest.path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Current file info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.BatchOperation.currentFile)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(state.processedFiles + 1) / \(state.totalFiles)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                Text(state.currentFileName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geo.size.width * state.bytesProgressFraction)
                            .animation(.easeInOut(duration: 0.2), value: state.bytesProgressFraction)
                    }
                }
                .frame(height: 8)
                
                // Progress text
                HStack {
                    Text(state.progressText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let remaining = state.estimatedTimeRemaining {
                        Text(L10n.BatchOperation.timeRemaining(formatTime(remaining)))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Error summary (if any)
            if !state.errors.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    
                    Text(L10n.BatchOperation.errorsCount(state.errors.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                if state.isCompleted || state.isCancelled {
                    // Show errors button (if any)
                    if !state.errors.isEmpty {
                        Button(action: showErrors) {
                            Text(L10n.BatchOperation.showErrors)
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    // Close button
                    HIGPrimaryButton(title: L10n.Button.ok, action: onDismiss)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Spacer()
                    
                    // Cancel button
                    Button(action: onCancel) {
                        Text(L10n.Button.cancel)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(minWidth: 80)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isHoveringCancel ? Color.red.opacity(0.9) : Color.red.opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringCancel = $0 }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Computed Properties
    
    private var operationIcon: Image {
        switch state.operationType {
        case .copy: return Image(systemName: "doc.on.doc")
        case .move: return Image(systemName: "arrow.right.doc.on.clipboard")
        case .delete: return Image(systemName: "trash")
        case .pack: return Image(systemName: "archivebox")
        }
    }
    
    private var progressColor: Color {
        if state.isCancelled {
            return .orange
        }
        if state.isCompleted {
            return state.errors.isEmpty ? .green : .orange
        }
        return .accentColor
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%d:%02d", mins, secs)
        } else {
            let hours = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            return String(format: "%d:%02d:00", hours, mins)
        }
    }
    
    private func showErrors() {
        // Show error details in alert
        let errorList = state.errors.prefix(10).map { "• \($0.fileName): \($0.error)" }.joined(separator: "\n")
        let message = state.errors.count > 10 
            ? "\(errorList)\n\n... and \(state.errors.count - 10) more"
            : errorList
        
        let alert = NSAlert()
        alert.messageText = L10n.BatchOperation.operationErrors
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Button.ok)
        alert.runModal()
    }
}

// MARK: - Preview
#Preview("Copying") {
    let state = BatchOperationState(
        operationType: .copy,
        sourcePanel: .left,
        destinationURL: URL(fileURLWithPath: "/Users/test/Documents"),
        files: [
            CustomFile(path: "/Users/test/file1.txt"),
            CustomFile(path: "/Users/test/file2.txt"),
            CustomFile(path: "/Users/test/file3.txt")
        ]
    )
    state.processedFiles = 1
    state.currentFileName = "file2.txt"
    state.processedBytes = 1024 * 1024
    state.totalBytes = 3 * 1024 * 1024
    
    return BatchProgressDialog(
        state: state,
        onCancel: {},
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Completed with errors") {
    let state = BatchOperationState(
        operationType: .move,
        sourcePanel: .left,
        destinationURL: URL(fileURLWithPath: "/Users/test/Backup"),
        files: [
            CustomFile(path: "/Users/test/file1.txt"),
            CustomFile(path: "/Users/test/file2.txt")
        ]
    )
    state.processedFiles = 2
    state.isCompleted = true
    state.errors = [
        OperationErrorInfo(fileName: "file1.txt", error: "Permission denied")
    ]
    
    return BatchProgressDialog(
        state: state,
        onCancel: {},
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

//
// FileTransferConfirmationDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

/// macOS HIG-compliant confirmation dialog for file move/copy operations
struct FileTransferConfirmationDialog: View {
    let operation: FileTransferOperation
    let onAction: (FileTransferAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private enum Layout {
        static let dialogWidth: CGFloat = 420
        static let iconSize: CGFloat = 64
        static let spacing: CGFloat = 16
        static let buttonSpacing: CGFloat = 8
        static let contentPadding: CGFloat = 20
    }
    
    var body: some View {
        VStack(spacing: Layout.spacing) {
            headerSection
            messageSection
            Spacer().frame(height: 8)
            buttonSection
        }
        .padding(Layout.contentPadding)
        .frame(width: Layout.dialogWidth)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onExitCommand {
            handleAction(.abort)
        }
    }
    
    // MARK: - Header with icon
    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder.fill")
                    .font(.system(size: Layout.iconSize))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white, .orange)
                    .offset(x: 8, y: 4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Move or Copy Items?")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Message section
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Do you want to move or copy \(operation.itemsDescription) to \"\(operation.destinationName)\"?")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 4) {
                if let firstFile = operation.sourceFiles.first {
                    HStack(spacing: 4) {
                        Text("From:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(firstFile.urlValue.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                HStack(spacing: 4) {
                    Text("To:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(operation.destinationPath.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Button section (macOS HIG order)
    private var buttonSection: some View {
        HStack(spacing: Layout.buttonSpacing) {
            Button {
                handleAction(.abort)
            } label: {
                Text("Cancel")
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            
            Spacer()
            
            Button {
                handleAction(.copy)
            } label: {
                Text("Copy")
                    .frame(minWidth: 70)
            }
            .buttonStyle(.bordered)
            
            Button {
                handleAction(.move)
            } label: {
                Text("Move")
                    .frame(minWidth: 70)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func handleAction(_ action: FileTransferAction) {
        log.debug("FileTransferConfirmationDialog: user selected \(action)")
        dismiss()
        onAction(action)
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

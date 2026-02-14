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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

            // File list (up to 5 items with "and N more")
            fileListSection

            // From / To paths
            VStack(alignment: .leading, spacing: 3) {
                if let firstFile = operation.sourceFiles.first {
                    pathRow(label: "From:", path: firstFile.urlValue.deletingLastPathComponent().path)
                }
                pathRow(label: "To:", path: operation.destinationPath.path)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - File list
    private var fileListSection: some View {
        let maxVisible = 5
        let files = operation.sourceFiles
        let visible = Array(files.prefix(maxVisible))
        let remaining = files.count - maxVisible

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(visible, id: \.id) { file in
                HStack(spacing: 6) {
                    Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(file.isDirectory ? .blue : .secondary)
                        .frame(width: 14)
                    Text(file.nameStr)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if remaining > 0 {
                Text("and \(remaining) more…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Path row helper
    private func pathRow(label: String, path: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
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

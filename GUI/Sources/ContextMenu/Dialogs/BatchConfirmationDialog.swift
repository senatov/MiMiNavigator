// BatchConfirmationDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Confirmation dialog for batch file operations

import SwiftUI

// MARK: - Batch Confirmation Dialog
/// Shows confirmation before batch copy/move/delete operations
struct BatchConfirmationDialog: View {
    let operationType: BatchOperationType
    let files: [CustomFile]
    let destination: URL?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var showFileList = false
    
    private var totalSize: String {
        let bytes = files.reduce(0) { $0 + $1.sizeInBytes }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private var directoriesCount: Int {
        files.filter { $0.isDirectory }.count
    }
    
    private var filesCount: Int {
        files.filter { !$0.isDirectory }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            operationIcon
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            
            // Title
            Text(titleText)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Summary info
            VStack(alignment: .leading, spacing: 6) {
                // Files/folders count
                HStack {
                    if filesCount > 0 {
                        Label("\(filesCount) files", systemImage: "doc")
                            .font(.system(size: 12))
                    }
                    if directoriesCount > 0 {
                        Label("\(directoriesCount) folders", systemImage: "folder")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(.secondary)
                
                // Total size
                HStack {
                    Text("Total size:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(totalSize)
                        .font(.system(size: 12, weight: .medium))
                }
                
                // Destination (for copy/move)
                if let dest = destination {
                    HStack(alignment: .top) {
                        Text("To:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(dest.path)
                            .font(.system(size: 12))
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            
            // Expandable file list
            DisclosureGroup(
                isExpanded: $showFileList,
                content: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(files.prefix(50), id: \.id) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(file.nameStr)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(file.fileSizeFormatted)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if files.count > 50 {
                                Text("... and \(files.count - 50) more")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                },
                label: {
                    Text("Show files")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            )
            .padding(.horizontal, 8)
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: L10n.Button.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(
                    title: confirmButtonTitle,
                    action: onConfirm,
                    isDestructive: operationType == .delete
                )
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
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
        switch operationType {
        case .copy: return Image(systemName: "doc.on.doc.fill")
        case .move: return Image(systemName: "arrow.right.doc.on.clipboard")
        case .delete: return Image(systemName: "trash.fill")
        case .pack: return Image(systemName: "archivebox.fill")
        }
    }
    
    private var iconColor: Color {
        switch operationType {
        case .copy: return .blue
        case .move: return .orange
        case .delete: return .red
        case .pack: return .purple
        }
    }
    
    private var titleText: String {
        switch operationType {
        case .copy:
            return L10n.BatchOperation.confirmCopy(files.count, destination?.lastPathComponent ?? "")
        case .move:
            return L10n.BatchOperation.confirmMove(files.count, destination?.lastPathComponent ?? "")
        case .delete:
            return L10n.BatchOperation.confirmDelete(files.count)
        case .pack:
            return "Pack \(files.count) items into archive?"
        }
    }
    
    private var confirmButtonTitle: String {
        switch operationType {
        case .copy: return L10n.Button.copy
        case .move: return L10n.Button.move
        case .delete: return L10n.Button.delete
        case .pack: return L10n.Button.create
        }
    }
}

// MARK: - Preview
#Preview("Copy") {
    BatchConfirmationDialog(
        operationType: .copy,
        files: [
            CustomFile(path: "/Users/test/document.txt"),
            CustomFile(path: "/Users/test/photo.jpg"),
            CustomFile(path: "/Users/test/folder")
        ],
        destination: URL(fileURLWithPath: "/Users/test/Backup"),
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Delete") {
    BatchConfirmationDialog(
        operationType: .delete,
        files: [
            CustomFile(path: "/Users/test/old_file.txt"),
            CustomFile(path: "/Users/test/temp")
        ],
        destination: nil,
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

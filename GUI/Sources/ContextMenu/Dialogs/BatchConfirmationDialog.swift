// BatchConfirmationDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Confirmation dialog for batch file operations

import SwiftUI
import FileModelKit

// MARK: - Batch Confirmation Dialog
/// Shows confirmation before batch copy/move/delete operations
struct BatchConfirmationDialog: View {
    let operationType: BatchOperationType
    let files: [CustomFile]
    let destination: URL?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var showFileList = false
    @State private var deleteEstimate: DeletePreviewEstimate?
    
    private var totalSize: String {
        if operationType == .delete, let deleteEstimate {
            return deleteEstimate.sizeText
        }
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
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.center)
            
            // Summary info
            VStack(alignment: .leading, spacing: 6) {
                // Files/folders count
                HStack {
                    if filesCount > 0 {
                        Label("\(filesCount) files", systemImage: "doc")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.multicolor)
                    }
                    if directoriesCount > 0 {
                        Label("\(directoriesCount) folders", systemImage: "folder")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .foregroundStyle(secondaryTextColor)
                
                // Total size
                HStack {
                    Text("Total size:")
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryTextColor)
                    Text(totalSize)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                }
                
                // Destination (for copy/move)
                if let dest = destination {
                    HStack(alignment: .top) {
                        Text("To:")
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTextColor)
                        Text(dest.path)
                            .font(.system(size: 12))
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                if operationType == .delete && directoriesCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recursive delete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(deleteEstimateText)
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
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
                                        .symbolRenderingMode(.multicolor)
                                    Text(file.nameStr)
                                        .font(.system(size: 11))
                                        .foregroundStyle(primaryTextColor)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(file.fileSizeFormatted)
                                        .font(.system(size: 10))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                            if files.count > 50 {
                                Text("... and \(files.count - 50) more")
                                    .font(.system(size: 11))
                                    .foregroundStyle(secondaryTextColor)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DialogColors.light)
                    )
                },
                label: {
                    Text("Show files")
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryTextColor)
                }
            )
            .padding(.horizontal, 8)
            
            Divider()
            
            // Buttons
            HIGDialogButtons(
                cancelTitle: L10n.Button.cancel,
                confirmTitle: confirmButtonTitle,
                isDestructive: operationType == .delete,
                isConfirmDisabled: operationType == .delete && directoriesCount > 0 && deleteEstimate == nil,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .padding(20)
        .frame(width: 380)
        .background(DialogColors.base)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
        .task(id: files.map(\.pathStr).joined(separator: "\u{1F}")) {
            guard operationType == .delete && directoriesCount > 0 else { return }
            deleteEstimate = await DeletePreviewEstimator.estimate(files: files.map(\.urlValue))
        }
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

    private var secondaryTextColor: Color {
        Color(#colorLiteral(red: 0.05, green: 0.16, blue: 0.30, alpha: 0.78))
    }

    private var primaryTextColor: Color {
        Color(#colorLiteral(red: 0.03, green: 0.10, blue: 0.18, alpha: 1.0))
    }

    private var deleteEstimateText: String {
        guard let deleteEstimate else {
            return "Calculating selected directories..."
        }
        let skipped = deleteEstimate.skippedCount > 0 ? "\nSome entries could not be scanned: \(deleteEstimate.skippedCount)." : ""
        return "\(deleteEstimate.summaryText).\(skipped)"
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

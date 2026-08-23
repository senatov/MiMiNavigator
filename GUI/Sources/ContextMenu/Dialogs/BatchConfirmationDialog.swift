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
    private let transferOperation: FileTransferOperation?
    private let onTransferAction: ((FileTransferAction) -> Void)?
    
    @State private var showFileList = false
    @State private var deleteEstimate: DeletePreviewEstimate?
    @State private var conflictCount = 0

    // MARK: - Initializers

    init(
        operationType: BatchOperationType,
        files: [CustomFile],
        destination: URL?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.operationType = operationType
        self.files = files
        self.destination = destination
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.transferOperation = nil
        self.onTransferAction = nil
    }

    init(operation: FileTransferOperation, onAction: @escaping (FileTransferAction) -> Void) {
        self.operationType = .copy
        self.files = operation.sourceFiles
        self.destination = operation.destinationPath
        self.onConfirm = { onAction(.copy) }
        self.onCancel = { onAction(.abort) }
        self.transferOperation = operation
        self.onTransferAction = onAction
    }
    
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
        let maximumSize = DialogWindowMetrics.maximumSize
        let dialogWidth = min(520, maximumSize.width)
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
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            
            FileOperationPreviewCard(rows: previewRows)
            VStack(alignment: .leading, spacing: 6) {
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
            dialogButtons
        }
        .keyboardFocusSection()
        .forcedDialogTabNavigation()
        .padding(20)
        .frame(width: dialogWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(DialogColors.base)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
        .task(id: files.map(\.pathStr).joined(separator: "\u{1F}")) {
            if operationType == .delete && directoriesCount > 0 {
                deleteEstimate = await DeletePreviewEstimator.estimate(files: files.map(\.urlValue))
            }
            guard operationType != .delete, let destination else { return }
            conflictCount = files.reduce(into: 0) { count, file in
                let target = destination.appendingPathComponent(file.urlValue.lastPathComponent)
                if FileManager.default.fileExists(atPath: target.path) { count += 1 }
            }
        }
    }
    
    // MARK: - Computed Properties

    @ViewBuilder
    private var dialogButtons: some View {
        if let onTransferAction {
            HStack(spacing: 10) {
                dialogButton(L10n.Button.cancel, shortcut: .cancelAction) { onTransferAction(.abort) }
                Spacer()
                dialogButton(L10n.Button.copy, shortcut: .defaultAction) { onTransferAction(.copy) }
                dialogButton(L10n.Button.move) { onTransferAction(.move) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        } else {
            HIGDialogButtons(
                cancelTitle: L10n.Button.cancel,
                confirmTitle: confirmButtonTitle,
                isDestructive: operationType == .delete,
                isConfirmDisabled: operationType == .delete && directoriesCount > 0 && deleteEstimate == nil,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }

    private func dialogButton(
        _ title: String,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .optionalKeyboardShortcut(shortcut)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.large)
            .focusable(true)
            .focusEffectDisabled()
    }
    
    private var operationIcon: Image {
        if transferOperation != nil { return Image(systemName: "folder.fill") }
        switch operationType {
        case .copy: return Image(systemName: "doc.on.doc.fill")
        case .move: return Image(systemName: "arrow.right.doc.on.clipboard")
        case .delete: return Image(systemName: "trash.fill")
        case .pack: return Image(systemName: "archivebox.fill")
        }
    }

    private var previewRows: [FileOperationPreviewRow] {
        var rows = [
            FileOperationPreviewRow(label: "From", value: sourceDescription, systemImage: "folder"),
            FileOperationPreviewRow(label: "Items", value: itemSummary, systemImage: "doc.on.doc"),
            FileOperationPreviewRow(label: "Total size", value: totalSize, systemImage: "externaldrive")
        ]
        let target = destination?.path ?? "Trash"
        rows.insert(FileOperationPreviewRow(label: "To", value: target, systemImage: operationType == .delete ? "trash" : "folder.badge.arrow.forward"), at: 1)
        if conflictCount > 0 {
            rows.append(FileOperationPreviewRow(label: "Conflicts", value: "\(conflictCount) will require a decision", systemImage: "exclamationmark.triangle"))
        }
        return rows
    }

    private var sourceDescription: String {
        let parents = Set(files.map { $0.urlValue.deletingLastPathComponent().path })
        return parents.count == 1 ? parents.first ?? "" : "Multiple locations"
    }

    private var itemSummary: String {
        [filesCount > 0 ? "\(filesCount) files" : nil, directoriesCount > 0 ? "\(directoriesCount) folders" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
    
    private var iconColor: Color {
        if transferOperation != nil { return .blue }
        switch operationType {
        case .copy: return .blue
        case .move: return .orange
        case .delete: return .red
        case .pack: return .purple
        }
    }
    
    private var titleText: String {
        if let transferOperation {
            return "Move or copy \(transferOperation.itemsDescription) to \"\(transferOperation.destinationName)\"?"
        }
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
        case .delete: return "Move to Trash"
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

// MARK: - Optional Keyboard Shortcut
private extension View {
    @ViewBuilder
    func optionalKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            keyboardShortcut(shortcut)
        } else {
            self
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

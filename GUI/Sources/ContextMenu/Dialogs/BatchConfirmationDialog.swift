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
    let onConfirm: (Bool) -> Void
    let onCancel: () -> Void
    private let transferOperation: FileTransferOperation?
    private let onTransferAction: ((FileTransferAction, Bool) -> Void)?
    
    @State private var showFileList = false
    @State private var deleteEstimate: DeletePreviewEstimate?
    @State private var conflictCount = 0
    @State private var runInBackground = false

    // MARK: - Initializers

    init(
        operationType: BatchOperationType,
        files: [CustomFile],
        destination: URL?,
        onConfirm: @escaping (Bool) -> Void,
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

    init(operation: FileTransferOperation, onAction: @escaping (FileTransferAction, Bool) -> Void) {
        self.operationType = .copy
        self.files = operation.sourceFiles
        self.destination = operation.destinationPath
        self.onConfirm = { onAction(.copy, $0) }
        self.onCancel = { onAction(.abort, false) }
        self.transferOperation = operation
        self.onTransferAction = onAction
    }
    
    private var totalSize: String {
        if operationType == .delete, directoriesCount > 0 {
            if isRemoteDelete { return "Unavailable for remote folders" }
            guard let deleteEstimate else { return "Calculating…" }
            return deleteEstimate.isApproximate || deleteEstimate.skippedCount > 0
                ? "Approximately \(deleteEstimate.sizeText)"
                : deleteEstimate.sizeText
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

    private var isRemoteDelete: Bool {
        operationType == .delete && files.contains { AppState.isRemotePath($0.urlValue) }
    }
    
    var body: some View {
        let maximumSize = DialogWindowMetrics.maximumSize
        let dialogWidth = min(520, maximumSize.width)
        let previewHeight = max(48, maximumSize.height - (operationType == .delete ? 510 : 438))
        VStack(spacing: 16) {
            DialogGlassIcon(systemName: operationIconName, tint: iconColor)
            
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
                        HStack(spacing: 6) {
                            if deleteEstimate == nil && !isRemoteDelete {
                                ProgressView().controlSize(.small)
                            }
                            Text(deleteEstimateText)
                                .font(.system(size: 11))
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            if operationType == .delete && !isRemoteDelete && files.count >= FileOpsEngine.bulkDeleteThreshold {
                Text("Large deletion moves items to Trash in batches. History keeps a summary; restore individual items from Trash.")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
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
                    .frame(maxHeight: previewHeight)
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
            if operationType != .pack {
                Toggle("Run in Background", isOn: $runInBackground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Buttons
            dialogButtons
        }
        .keyboardFocusSection()
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
        .task {
            if operationType == .delete && directoriesCount > 0 && !isRemoteDelete {
                deleteEstimate = await DeletePreviewEstimator.estimate(files: files.map(\.urlValue))
            }
            guard operationType != .delete, let destination, destination.isFileURL,
                  !files.contains(where: { AppState.isRemotePath($0.urlValue) }) else { return }
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
                dialogButton(L10n.Button.cancel, systemImage: "xmark", iconTint: .red, shortcut: .cancelAction, action: onCancel)
                Spacer()
                dialogButton(L10n.Button.copy, systemImage: "doc.on.doc", iconTint: .blue, shortcut: .defaultAction) { onTransferAction(.copy, runInBackground) }
                dialogButton(L10n.Button.move, systemImage: "arrow.right", iconTint: Color(nsColor: #colorLiteral(red: 0.09309739884, green: 0.6279325638, blue: 1, alpha: 1))) { onTransferAction(.move, runInBackground) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        } else {
            HIGDialogButtons(
                cancelTitle: L10n.Button.cancel,
                confirmTitle: confirmButtonTitle,
                isDestructive: operationType == .delete,
                isConfirmDisabled: operationType == .delete && directoriesCount > 0 && !isRemoteDelete && deleteEstimate == nil,
                onCancel: onCancel,
                onConfirm: { onConfirm(runInBackground) }
            )
        }
    }

    private func dialogButton(
        _ title: String,
        systemImage: String,
        iconTint: Color,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) -> some View {
        DownToolbarButtonView(title: title, systemImage: systemImage, iconTint: iconTint, action: action)
            .optionalKeyboardShortcut(shortcut)
    }
    
    private var operationIconName: String {
        if transferOperation != nil { return "folder.fill" }
        switch operationType {
        case .copy: return "doc.on.doc.fill"
        case .move: return "arrow.right.doc.on.clipboard"
        case .delete: return "trash.fill"
        case .pack: return "archivebox.fill"
        }
    }

    private var previewRows: [FileOperationPreviewRow] {
        var rows = [
            FileOperationPreviewRow(label: "From", value: sourceDescription, systemImage: "folder"),
            FileOperationPreviewRow(label: "Items", value: itemSummary, systemImage: "doc.on.doc"),
            FileOperationPreviewRow(label: "Total size", value: totalSize, systemImage: "externaldrive")
        ]
        let target = destination?.path ?? (isRemoteDelete ? "Remote server (permanent)" : "Trash")
        rows.insert(FileOperationPreviewRow(label: "To", value: target, systemImage: operationType == .delete ? "trash" : "folder"), at: 1)
        if conflictCount > 0 {
            rows.append(FileOperationPreviewRow(label: "Conflicts", value: "\(conflictCount) will require a decision", systemImage: "exclamationmark.triangle"))
        }
        return rows
    }

    private var sourceDescription: String {
        guard let first = files.first else { return "" }
        let parent = first.urlValue.deletingLastPathComponent().path
        return files.dropFirst().allSatisfy { $0.urlValue.deletingLastPathComponent().path == parent }
            ? parent
            : "Multiple locations"
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
        case .delete: return DialogGlassIcon.destructiveTint
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
            return isRemoteDelete
                ? "Permanently delete \(files.count) selected item(s) from the remote server?"
                : L10n.BatchOperation.confirmDelete(files.count)
        case .pack:
            return "Pack \(files.count) items into archive?"
        }
    }
    
    private var confirmButtonTitle: String {
        switch operationType {
        case .copy: return L10n.Button.copy
        case .move: return L10n.Button.move
        case .delete: return isRemoteDelete ? "Delete" : "Move to Trash"
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
        if isRemoteDelete {
            return "The remote server has no Trash. Selected directories and all of their contents will be deleted permanently."
        }
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
        onConfirm: { _ in },
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
        onConfirm: { _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

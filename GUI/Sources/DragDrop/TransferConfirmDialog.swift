// TransferConfirmDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: macOS HIG confirmation dialog for move/copy file operations

import SwiftUI


// MARK: - FileTransferConfirmationDialog
/// HIG-style confirmation dialog: app icon top-left, bold question, path rows, native buttons.
struct FileTransferConfirmationDialog: View {
    let operation: FileTransferOperation
    let onAction: (FileTransferAction) -> Void
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection.padding(.bottom, 12)
            fileListSection.padding(.bottom, 8)
            pathSection.padding(.bottom, 20)
            buttonSection
        }
        .padding(20)
        .frame(width: 400)
        .background(DialogColors.base)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }


    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .orange)
                    .offset(x: 6, y: 4)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("Move or Copy Items?")
                    .font(.system(size: 14, weight: .light))
                Text("Do you want to move or copy \(operation.itemsDescription) to \"\(operation.destinationName)\"?")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }


    // MARK: - File List
    private var fileListSection: some View {
        let maxVisible = 5
        let files = operation.sourceFiles
        let visible = Array(files.prefix(maxVisible))
        let remaining = files.count - maxVisible
        return VStack(alignment: .leading, spacing: 3) {
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


    // MARK: - Path Rows
    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let firstFile = operation.sourceFiles.first {
                pathRow(label: "From:", path: firstFile.urlValue.deletingLastPathComponent().path)
            }
            pathRow(label: "To:", path: operation.destinationPath.path)
        }
    }


    private func pathRow(label: String, path: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
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


    // MARK: - Buttons
    private var buttonSection: some View {
        HStack(spacing: 8) {
            DownToolbarButtonView(title: "Cancel", systemImage: "xmark") { handleAction(.abort) }
                .keyboardShortcut(.cancelAction)
            Spacer()
            DownToolbarButtonView(title: "Copy", systemImage: "doc.on.doc") { handleAction(.copy) }
                .keyboardShortcut(.defaultAction)
            DownToolbarButtonView(title: "Move", systemImage: "arrow.right") { handleAction(.move) }
        }
    }


    // MARK: - Handle Action
    private func handleAction(_ action: FileTransferAction) {
        log.debug("[TransferDialog] action=\(action)")
        dismiss()
        onAction(action)
    }
}

//  ConfirmationDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import SwiftUI

// MARK: - DeleteConfirmationDialog
struct DeleteConfirmationDialog: View {
    let files: [CustomFile]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    private var itemsDescription: String {
        files.count == 1 ? "\"\(files[0].nameStr)\"" : "\(files.count) items"
    }
    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(
                "Do you want to move \(itemsDescription) to Trash?",
                subtitle: files.count == 1 ? files[0].urlValue.deletingLastPathComponent().path : nil
            )
            HIGDialogButtons(
                confirmTitle: "Move to Trash",
                isDestructive: true,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .higDialogStyle()
    }
}

// MARK: - GenericConfirmationDialog
struct GenericConfirmationDialog: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    init(
        title: String,
        message: String? = nil,
        confirmTitle: String = "OK",
        cancelTitle: String = "Cancel",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(title, subtitle: message)
            HIGDialogButtons(
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                isDestructive: isDestructive,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .higDialogStyle()
    }
}

// MARK: - Previews
#Preview("Delete Single File") {
    DeleteConfirmationDialog(
        files: [CustomFile(path: "/Users/test/document.txt")],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Delete Multiple") {
    DeleteConfirmationDialog(
        files: [
            CustomFile(path: "/Users/test/file1.txt"),
            CustomFile(path: "/Users/test/file2.txt"),
        ],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Generic") {
    GenericConfirmationDialog(
        title: "Do you want to duplicate items here?",
        message: "/Users/senat/Downloads/Musor",
        confirmTitle: "OK",
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

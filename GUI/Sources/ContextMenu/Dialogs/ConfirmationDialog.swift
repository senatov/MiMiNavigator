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
    @State private var estimate: DeletePreviewEstimate?
    private var itemsDescription: String {
        files.count == 1 ? "\"\(files[0].nameStr)\"" : "\(files.count) items"
    }
    private var hasDirectories: Bool {
        files.contains { $0.isDirectory }
    }
    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(
                "Do you want to move \(itemsDescription) to Trash?",
                subtitle: files.count == 1 ? files[0].urlValue.deletingLastPathComponent().path : nil
            )
            if hasDirectories {
                directoryWarning
            }
            HIGDialogButtons(
                confirmTitle: "Move to Trash",
                isDestructive: true,
                isConfirmDisabled: hasDirectories && estimate == nil,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .higDialogStyle()
        .task(id: files.map(\.pathStr).joined(separator: "\u{1F}")) {
            guard hasDirectories else { return }
            estimate = await DeletePreviewEstimator.estimate(files: files.map(\.urlValue))
        }
    }
    private var directoryWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recursive delete")
                .font(.system(size: 12, weight: .semibold))
            Text(directoryWarningText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    private var directoryWarningText: String {
        guard let estimate else {
            return "Calculating selected directories..."
        }
        let skipped = estimate.skippedCount > 0 ? "\nSome entries could not be scanned: \(estimate.skippedCount)." : ""
        let label = estimate.rootDirectoryCount == 1 ? "directory" : "directories"
        return "This includes \(estimate.rootDirectoryCount) \(label): \(estimate.summaryText).\(skipped)"
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

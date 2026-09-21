// CreateFolderDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: HIG-style Create New Folder dialog.

import SwiftUI

// MARK: - Create Folder Dialog
struct CreateFolderDialog: View {
    let parentURL: URL
    let onCreateFolder: (String) -> Void
    let onCancel: () -> Void
    var body: some View {
        CreateItemDialog(
            parentURL: parentURL,
            configuration: CreateItemDialogConfiguration(
                title: L10n.Dialog.CreateFolder.title,
                defaultName: L10n.Dialog.CreateFolder.defaultName,
                enterNameLabel: L10n.Dialog.CreateFolder.enterNameLabel,
                placeholder: L10n.Dialog.CreateFolder.placeholder,
                emptyNameError: L10n.Error.folderNameEmpty,
                invalidNameError: L10n.Error.nameInvalidCharsExtended,
                systemImage: "folder.badge.plus"
            ),
            onCreate: onCreateFolder,
            onCancel: onCancel
        )
    }
}

// MARK: - Preview
#Preview {
    CreateFolderDialog(parentURL: URL(fileURLWithPath: "/Users/test/Documents"), onCreateFolder: { _ in }, onCancel: {})
        .padding(40)
}

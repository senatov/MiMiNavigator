// CreateFileDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: HIG-style Create New File dialog.

import SwiftUI

// MARK: - Create File Dialog
struct CreateFileDialog: View {
    let parentURL: URL
    let onCreateFile: (String) -> Void
    let onCancel: () -> Void
    var body: some View {
        CreateItemDialog(
            parentURL: parentURL,
            configuration: CreateItemDialogConfiguration(
                title: L10n.Dialog.CreateFile.title,
                defaultName: L10n.Dialog.CreateFile.defaultName,
                enterNameLabel: L10n.Dialog.CreateFile.enterNameLabel,
                placeholder: L10n.Dialog.CreateFile.placeholder,
                emptyNameError: L10n.Error.fileNameEmpty,
                invalidNameError: L10n.Error.fileNameInvalidCharsExtended,
                systemImage: "doc.badge.plus"
            ),
            onCreate: onCreateFile,
            onCancel: onCancel
        )
    }
}

// MARK: - Preview
#Preview {
    CreateFileDialog(parentURL: URL(fileURLWithPath: "/Users/test/Documents"), onCreateFile: { _ in }, onCancel: {})
        .padding(40)
}

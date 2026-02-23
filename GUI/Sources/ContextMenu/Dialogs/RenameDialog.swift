// RenameDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Rename Dialog
struct RenameDialog: View {
    let file: CustomFile
    let onRename: (String) -> Void
    let onCancel: () -> Void

    @State private var newName: String
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    init(file: CustomFile, onRename: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        log.debug(#function)
        self.file = file
        self.onRename = onRename
        self.onCancel = onCancel
        self._newName = State(initialValue: file.nameStr)
    }

    private var isValidName: Bool {
        !newName.isEmpty && !newName.contains("/") && !newName.contains(":") && newName != "." && newName != ".."
    }

    private var hasChanges: Bool {
        newName != file.nameStr
    }

    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(
                file.isDirectory ? L10n.Dialog.Rename.titleFolder : L10n.Dialog.Rename.titleFile,
                subtitle: file.urlValue.deletingLastPathComponent().path
            )

            // Input field
            VStack(alignment: .leading, spacing: 6) {
                HIGTextField(
                    label: L10n.PathInput.nameLabel,
                    placeholder: L10n.PathInput.nameLabel,
                    text: $newName,
                    hasError: errorMessage != nil
                )
                .focused($isTextFieldFocused)
                .onSubmit {
                    if isValidName && hasChanges { onRename(newName) }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)

            HIGDialogButtons(
                confirmTitle: L10n.Button.rename,
                isConfirmDisabled: !isValidName || !hasChanges,
                onCancel: onCancel,
                onConfirm: { onRename(newName) }
            )
        }
        .higDialogStyle()
        .onAppear { isTextFieldFocused = true }
        .onChange(of: newName) { _, newValue in validateName(newValue) }
    }

    private func validateName(_ name: String) {
        log.debug(#function)
        if name.isEmpty {
            errorMessage = L10n.Error.nameEmpty
        } else if name.contains("/") || name.contains(":") {
            errorMessage = L10n.Error.nameInvalidChars
        } else if name == "." || name == ".." {
            errorMessage = L10n.Error.invalidNameGeneric
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - Preview
#Preview {
    RenameDialog(
        file: CustomFile(path: "/Users/test/document.txt"),
        onRename: { _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

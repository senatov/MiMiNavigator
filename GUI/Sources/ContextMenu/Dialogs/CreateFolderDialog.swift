// CreateFolderDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI HIG-style Create New Folder dialog

import SwiftUI
import FileModelKit

// MARK: - Create Folder Dialog
/// SwiftUI HIG-style dialog matching PackDialog / BatchConfirmationDialog appearance.
struct CreateFolderDialog: View {
    let parentURL: URL
    let onCreateFolder: (String) -> Void
    let onCancel: () -> Void

    @State private var folderName: String
    @State private var errorMessage: String?
    @FocusState private var isNameFieldFocused: Bool

    init(
        parentURL: URL,
        onCreateFolder: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.parentURL = parentURL
        self.onCreateFolder = onCreateFolder
        self.onCancel = onCancel
        self._folderName = State(initialValue: L10n.Dialog.CreateFolder.defaultName)
    }

    private var isValidName: Bool {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let invalidChars = CharacterSet(charactersIn: ":/\\")
        return trimmed.rangeOfCharacter(from: invalidChars) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HIGDialogHeader(
                L10n.Dialog.CreateFolder.title,
                subtitle: parentURL.path
            )
            .frame(maxWidth: .infinity)

            HIGTextField(
                label: L10n.Dialog.CreateFolder.enterNameLabel,
                placeholder: L10n.Dialog.CreateFolder.placeholder,
                text: $folderName,
                hasError: !isValidName && !folderName.isEmpty,
                focusState: $isNameFieldFocused
            )

            if !folderName.isEmpty && !isValidName {
                Text(L10n.Error.nameInvalidCharsExtended)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HIGDialogButtons(
                confirmTitle: L10n.Button.create,
                isConfirmDisabled: !isValidName,
                onCancel: onCancel,
                onConfirm: performCreate
            )
        }
        .higDialogStyle()
        .higAutoFocusTextField()
        .frame(minWidth: 380)
        .onAppear { isNameFieldFocused = true }
    }

    private func performCreate() {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.Error.folderNameEmpty
            return
        }
        onCreateFolder(trimmed)
    }
}

// MARK: - Preview
#Preview {
    CreateFolderDialog(
        parentURL: URL(fileURLWithPath: "/Users/test/Documents"),
        onCreateFolder: { _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

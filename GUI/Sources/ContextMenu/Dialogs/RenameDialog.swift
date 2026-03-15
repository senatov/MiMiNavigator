    // RenameDialog.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 22.01.2026.
    //  Copyright © 2026 Senatov. All rights reserved.

    import SwiftUI
    import FileModelKit

    // MARK: - Rename Dialog
    struct RenameDialog: View {
        let file: CustomFile
        let onRename: (String) -> Void
        let onCancel: () -> Void

        @State private var newName: String
        @State private var errorMessage: String?
        @State private var showOverwriteAlert: Bool = false
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
                        confirmRename()
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
                    onConfirm: { confirmRename() }
                )
            }
            .higDialogStyle()
            .higAutoFocusTextField()
            .onAppear { isTextFieldFocused = true }
            .onChange(of: newName) { _, newValue in validateName(newValue) }
            .alert("File already exists", isPresented: $showOverwriteAlert) {
                Button("Cancel", role: .cancel) {
                    isTextFieldFocused = true
                }
                Button("Overwrite", role: .destructive) {
                    onRename(newName)
                }
            } message: {
                Text("A file named \(newName) already exists. Do you want to replace it?")
            }
        }

        private func confirmRename() {
            guard isValidName && hasChanges else {
                log.warning("[RenameDialog] confirmRename: guard failed — isValidName=\(isValidName) hasChanges=\(hasChanges)")
                return
            }

            let dir = file.urlValue.deletingLastPathComponent()
            let targetURL = dir.appendingPathComponent(newName)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                log.info("[RenameDialog] target exists, showing overwrite alert: '\(targetURL.path)'")
                showOverwriteAlert = true
                return
            }

            log.info("[RenameDialog] ✅ confirmRename: calling onRename('\(newName)')")
            onRename(newName)
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

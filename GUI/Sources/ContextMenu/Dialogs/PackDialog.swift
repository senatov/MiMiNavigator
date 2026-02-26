// PackDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI
import FileModelKit

// MARK: - Pack Dialog
struct PackDialog: View {
    let files: [CustomFile]
    let initialDestination: URL
    /// Callback: (archiveName, format, destination, deleteSourceFiles)
    let onPack: (String, ArchiveFormat, URL, Bool) -> Void
    let onCancel: () -> Void

    @State private var archiveName: String
    @State private var destinationPath: String
    @State private var selectedFormat: ArchiveFormat = .zip
    @State private var deleteSourceFiles: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isNameFieldFocused: Bool

    init(
        files: [CustomFile],
        destinationPath: URL,
        onPack: @escaping (String, ArchiveFormat, URL, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.files = files
        self.initialDestination = destinationPath
        self.onPack = onPack
        self.onCancel = onCancel

        let defaultName: String
        if files.count == 1 {
            defaultName = files[0].urlValue.deletingPathExtension().lastPathComponent
        } else {
            defaultName = "Archive"
        }
        self._archiveName = State(initialValue: defaultName)
        self._destinationPath = State(initialValue: destinationPath.path)
    }

    private var isValidName: Bool {
        !archiveName.isEmpty && !archiveName.contains("/") && !archiveName.contains(":")
    }

    private var isValidDestination: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: destinationPath, isDirectory: &isDir) && isDir.boolValue
    }

    private var itemsDescription: String {
        files.count == 1 ? files[0].nameStr : L10n.Items.count(files.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HIGDialogHeader(L10n.Dialog.Pack.title(itemsDescription))
                .frame(maxWidth: .infinity)

            // Archive name
            VStack(alignment: .leading, spacing: 6) {
                HIGTextField(
                    label: L10n.Dialog.Pack.archiveNameLabel,
                    placeholder: L10n.PathInput.nameLabel,
                    text: $archiveName,
                    hasError: !isValidName && !archiveName.isEmpty
                )
                .focused($isNameFieldFocused)
            }

            // Destination path
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.Pack.saveToLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    TextField(L10n.PathInput.pathLabel, text: $destinationPath)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    !isValidDestination ? Color.red.opacity(0.7) : Color(nsColor: .separatorColor),
                                    lineWidth: 1
                                )
                        )

                    Button(action: browseForFolder) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(ThemedButtonStyle())
                    .controlSize(.regular)
                }
            }

            // Format picker — .menu dropdown (macOS Settings style)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.Pack.formatLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Picker("", selection: $selectedFormat) {
                    ForEach(ArchiveFormat.availableFormats) { format in
                        Text(".\(format.fileExtension)  —  \(format.displayName)").tag(format)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Delete source toggle
            Toggle(isOn: $deleteSourceFiles) {
                Text("Delete source files after packing")
                    .font(.system(size: 13))
            }
            .toggleStyle(.checkbox)

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HIGDialogButtons(
                confirmTitle: L10n.Button.create,
                isConfirmDisabled: !isValidName || !isValidDestination,
                onCancel: onCancel,
                onConfirm: performPack
            )
        }
        .higDialogStyle()
        .frame(minWidth: 380)
        .onAppear { isNameFieldFocused = true }
    }

    private func performPack() {
        onPack(archiveName, selectedFormat, URL(fileURLWithPath: destinationPath), deleteSourceFiles)
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.Button.select
        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }
}

// MARK: - Preview
#Preview {
    PackDialog(
        files: [CustomFile(path: "/Users/test/document.txt")],
        destinationPath: URL(fileURLWithPath: "/Users/test"),
        onPack: { _, _, _, _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

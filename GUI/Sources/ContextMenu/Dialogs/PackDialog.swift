    // PackDialog.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 22.01.2026.
    //  Copyright © 2026 Senatov. All rights reserved.

    import SwiftUI
    import FileModelKit

    // MARK: - Pack Dialog Mode

    enum PackDialogMode {
        case pack
        case compress
    }

    // MARK: - Pack Dialog
    struct PackDialog: View {
        let mode: PackDialogMode
        let files: [CustomFile]
        let initialDestination: URL
        /// Callback: (archiveName, format, destination, deleteSourceFiles)
        let onPack: (String, ArchiveFormat, URL, Bool) -> Void
        let onCancel: () -> Void
        private static let lastArchiveDirectoryKey = "LastArchiveDirectory"

        @State private var archiveName: String
        @State private var destinationPath: String
        @State private var selectedFormat: ArchiveFormat = .zip
        @State private var deleteSourceFiles: Bool = false
        @State private var errorMessage: String?
        @FocusState private var isNameFieldFocused: Bool

        init(
            mode: PackDialogMode = .pack,
            files: [CustomFile],
            destinationPath: URL,
            onPack: @escaping (String, ArchiveFormat, URL, Bool) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.mode = mode
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

            let defaultFormat: ArchiveFormat = .zip

            if mode == .compress {
                self._archiveName = State(initialValue: defaultName + "." + defaultFormat.fileExtension)
            } else {
                self._archiveName = State(initialValue: defaultName)
            }
            self._selectedFormat = State(initialValue: defaultFormat)
            // Use last directory ONLY if it's non-empty, not ".", and actually exists
            let lastDir = MiMiDefaults.shared.string(forKey: Self.lastArchiveDirectoryKey)
            let validLastDir: String? = {
                guard let dir = lastDir, !dir.isEmpty, dir != ".", dir != ".." else { return nil }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { return nil }
                return dir
            }()
            self._destinationPath = State(initialValue: validLastDir ?? destinationPath.path)
        }

        private var isValidName: Bool {
            !archiveName.isEmpty && !archiveName.contains("/") && !archiveName.contains(":")
        }

        /// Destination must be absolute path to an existing directory
        private var isValidDestination: Bool {
            // Must be absolute path — reject ".", "..", "./foo", etc.
            guard destinationPath.hasPrefix("/") else {
                log.warning("[PackDialog] Invalid destination: '\(destinationPath)' — not absolute path")
                return false
            }
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: destinationPath, isDirectory: &isDir)
            if !exists || !isDir.boolValue {
                log.warning("[PackDialog] Invalid destination: '\(destinationPath)' — exists=\(exists) isDir=\(isDir.boolValue)")
            }
            return exists && isDir.boolValue
        }

        private var itemsDescription: String {
            files.count == 1 ? files[0].nameStr : L10n.Items.count(files.count)
        }

        private var dialogTitle: String {
            switch mode {
                case .pack:
                    return L10n.Dialog.Pack.title(itemsDescription)
                case .compress:
                    return files.count == 1 ? "Compress \(itemsDescription)" : "Compress \(files.count) Items"
            }
        }

        private var confirmTitle: String {
            switch mode {
                case .pack:
                    return L10n.Button.create
                case .compress:
                    return "Compress"
            }
        }

        private var deleteToggleTitle: String {
            switch mode {
                case .pack:
                    return "Delete source files after packing"
                case .compress:
                    return "Move originals into archive"
            }
        }

        private var showsFormatPicker: Bool {
            true
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HIGDialogHeader(dialogTitle)
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

                if showsFormatPicker {
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
                }

                // Delete source toggle
                Toggle(isOn: $deleteSourceFiles) {
                    Text(deleteToggleTitle)
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
                    confirmTitle: confirmTitle,
                    isConfirmDisabled: !isValidName || !isValidDestination,
                    onCancel: onCancel,
                    onConfirm: performPack
                )
            }
            .higDialogStyle()
            .higAutoFocusTextField()
            .frame(minWidth: 380)
            .onAppear { isNameFieldFocused = true }
        }

        private func performPack() {
            log.info("[PackDialog] \(#function) archiveName='\(archiveName)' dest='\(destinationPath)' format=\(selectedFormat) deleteSource=\(deleteSourceFiles)")
            
            // Only save destination if it's a valid absolute path
            if destinationPath.hasPrefix("/") && isValidDestination {
                MiMiDefaults.shared.set(destinationPath, forKey: Self.lastArchiveDirectoryKey)
            } else {
                log.warning("[PackDialog] Not saving invalid destination: '\(destinationPath)'")
            }

            let format: ArchiveFormat = selectedFormat
            let destURL = URL(fileURLWithPath: destinationPath)
            log.info("[PackDialog] Final destURL='\(destURL.path)' absolutePath='\(destURL.absoluteURL.path)'")
            onPack(archiveName, format, destURL, deleteSourceFiles)
        }

        private func browseForFolder() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = L10n.Button.select

            if FileManager.default.fileExists(atPath: destinationPath) {
                panel.directoryURL = URL(fileURLWithPath: destinationPath)
            }

            if panel.runModal() == .OK, let url = panel.url {
                destinationPath = url.path
            }
        }
    }

    // MARK: - Preview
    #Preview {
        PackDialog(
            mode: .pack,
            files: [CustomFile(path: "/Users/test/document.txt")],
            destinationPath: URL(fileURLWithPath: "/Users/test"),
            onPack: { _, _, _, _ in },
            onCancel: {}
        )
        .padding(40)
        .background(Color.gray.opacity(0.3))
    }

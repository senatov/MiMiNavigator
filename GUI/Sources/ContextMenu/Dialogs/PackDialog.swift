// PackDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Pack Dialog (HIG Style)
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
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            // Title
            Text(L10n.Dialog.Pack.title(itemsDescription))
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Archive name
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.Pack.archiveNameLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                TextField(L10n.PathInput.nameLabel, text: $archiveName)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(!isValidName ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                    .focused($isNameFieldFocused)
            }
            .frame(maxWidth: 320)
            
            // Destination path
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.Pack.saveToLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    TextField(L10n.PathInput.pathLabel, text: $destinationPath)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(!isValidDestination ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    Button(action: browseForFolder) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: 320)
            
            // Format picker
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.Pack.formatLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedFormat) {
                    ForEach(ArchiveFormat.availableFormats) { format in
                        Text(".\(format.fileExtension) — \(format.displayName)")
                            .tag(format)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .frame(maxWidth: 320, alignment: .leading)
            
            // Delete source option
            Toggle(isOn: $deleteSourceFiles) {
                Text("Delete source files after packing")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: 320, alignment: .leading)
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: L10n.Button.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: L10n.Button.create, action: performPack)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidName || !isValidDestination)
                    .opacity(isValidName && isValidDestination ? 1.0 : 0.5)
            }
            .padding(.top, 4)
        }
        .higDialogStyle()
        .frame(minWidth: 360)
        .onAppear {
            isNameFieldFocused = true
        }
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

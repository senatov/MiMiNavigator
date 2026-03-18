//  PackDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Updated by Claude on 18.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Enhanced pack dialog with destination selector, compression levels, passwords

import SwiftUI
import FileModelKit

// MARK: - Pack Dialog Mode

enum PackDialogMode {
    case pack
    case compress
}

// MARK: - Pack Dialog

struct PackDialog: View {
    @Environment(AppState.self) var appState
    
    let mode: PackDialogMode
    let files: [CustomFile]
    let sourcePanel: PanelSide
    /// Callback: (archiveName, format, destination, deleteSourceFiles, compressionLevel, password)
    let onPack: (String, ArchiveFormat, URL, Bool, CompressionLevel, String?) -> Void
    let onCancel: () -> Void
    
    @StateObject private var prefs = ArchivePreferencesStore.shared
    
    @State private var archiveName: String
    @State private var selectedFormat: ArchiveFormat
    @State private var destinationMode: ArchivePreferencesStore.DestinationMode
    @State private var customDestination: String
    @State private var deleteSourceFiles: Bool = false
    @State private var compressionLevel: CompressionLevel
    @State private var usePassword: Bool = false
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isAppearing: Bool = false
    
    @FocusState private var isNameFieldFocused: Bool
    
    // MARK: - Init
    
    init(
        mode: PackDialogMode = .pack,
        files: [CustomFile],
        sourcePanel: PanelSide,
        onPack: @escaping (String, ArchiveFormat, URL, Bool, CompressionLevel, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.files = files
        self.sourcePanel = sourcePanel
        self.onPack = onPack
        self.onCancel = onCancel
        
        // Default archive name: single file → filename, multiple → archive_DDmmYYYY_HH_MM_SS
        let defaultName: String
        if files.count == 1 {
            defaultName = files[0].urlValue.deletingPathExtension().lastPathComponent
        } else {
            let df = DateFormatter()
            df.dateFormat = "ddMMyyyy_HH_mm_ss"
            defaultName = "archive_\(df.string(from: Date()))"
        }
        
        // Load saved preferences
        let savedFormat = ArchivePreferencesStore.shared.lastFormat
        let savedMode = ArchivePreferencesStore.shared.destinationMode
        let savedCustom = ArchivePreferencesStore.shared.customDestination
        let savedLevel = ArchivePreferencesStore.shared.compressionLevel(for: savedFormat)
        
        if mode == .compress {
            self._archiveName = State(initialValue: defaultName + "." + savedFormat.fileExtension)
        } else {
            self._archiveName = State(initialValue: defaultName)
        }
        self._selectedFormat = State(initialValue: savedFormat)
        self._destinationMode = State(initialValue: savedMode)
        self._customDestination = State(initialValue: savedCustom)
        self._compressionLevel = State(initialValue: savedLevel)
    }
    
    // MARK: - Computed Properties
    
    private var isValidName: Bool {
        !archiveName.isEmpty && !archiveName.contains("/") && !archiveName.contains(":")
    }
    
    /// Resolved destination URL based on mode
    private var resolvedDestination: URL {
        switch destinationMode {
        case .currentPanel:
            return URL(fileURLWithPath: appState.path(for: sourcePanel))
        case .oppositePanel:
            let opposite: PanelSide = sourcePanel == .left ? .right : .left
            return URL(fileURLWithPath: appState.path(for: opposite))
        case .custom:
            return URL(fileURLWithPath: customDestination)
        }
    }
    
    private var isValidDestination: Bool {
        let path = resolvedDestination.path
        guard path.hasPrefix("/") else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
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
        mode == .pack ? L10n.Button.create : "Compress"
    }
    
    private var supportsCompression: Bool {
        prefs.supportsCompression(selectedFormat)
    }
    
    private var supportsPassword: Bool {
        prefs.supportsPassword(selectedFormat)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HIGDialogHeader(dialogTitle)
                .frame(maxWidth: .infinity)
            
            // Archive name
            HIGTextField(
                label: L10n.Dialog.Pack.archiveNameLabel,
                placeholder: L10n.PathInput.nameLabel,
                text: $archiveName,
                hasError: !isValidName && !archiveName.isEmpty
            )
            .focused($isNameFieldFocused)
            
            // Destination selector — 3 buttons
            destinationSelector
            
            // Format picker
            formatPicker
            
            // Compression level (if supported)
            if supportsCompression {
                compressionPicker
            }
            
            // Password (if supported)
            if supportsPassword {
                passwordSection
            }
            
            // Delete source toggle
            Toggle(isOn: $deleteSourceFiles) {
                Text(mode == .pack ? "Delete source files after packing" : "Move originals into archive")
                    .font(.system(size: 13))
            }
            .toggleStyle(.checkbox)
            
            HIGDialogButtons(
                confirmTitle: confirmTitle,
                isConfirmDisabled: !isValidName || !isValidDestination,
                onCancel: onCancel,
                onConfirm: performPack
            )
        }
        .higDialogStyle()
        .higAutoFocusTextField()
        .frame(minWidth: 420)
        .scaleEffect(isAppearing ? 1.0 : 0.9)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            isNameFieldFocused = true
            // Load password from Keychain if enabled
            if prefs.useKeychainPasswords, let saved = ArchivePasswordStore.shared.loadPassword() {
                password = saved
                usePassword = !saved.isEmpty
            }
            // Spring animation on appear
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
    }
    
    // MARK: - Destination Selector
    
    private var destinationSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Dialog.Pack.saveToLabel)
                .font(.system(size: 12, weight: .medium))
            
            HStack(spacing: 8) {
                // Current panel button
                destinationButton(
                    mode: .currentPanel,
                    label: "Current",
                    icon: "folder",
                    shortcut: "1"
                )
                
                // Opposite panel button
                destinationButton(
                    mode: .oppositePanel,
                    label: "Opposite",
                    icon: "arrow.left.arrow.right",
                    shortcut: "2"
                )
                
                // Custom button + browse
                HStack(spacing: 4) {
                    destinationButton(
                        mode: .custom,
                        label: "Other…",
                        icon: "folder.badge.gearshape",
                        shortcut: "3"
                    )
                    
                    if destinationMode == .custom {
                        Button(action: browseForFolder) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Show resolved path
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(resolvedDestination.path)
                    .font(.system(size: 11))
                    .foregroundColor(isValidDestination ? .secondary : .red)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 4)
        }
    }
    
    private func destinationButton(
        mode: ArchivePreferencesStore.DestinationMode,
        label: String,
        icon: String,
        shortcut: String
    ) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                destinationMode = mode
                prefs.updateDestinationMode(mode)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(destinationMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(destinationMode == mode ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(shortcut)), modifiers: [])
    }
    
    // MARK: - Format Picker
    
    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Dialog.Pack.formatLabel)
                .font(.system(size: 12, weight: .medium))
            
            Picker("", selection: $selectedFormat) {
                ForEach(ArchiveFormat.availableFormats) { format in
                    HStack {
                        Image(systemName: format.icon)
                        Text(".\(format.fileExtension) — \(format.displayName)")
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: selectedFormat) { _, newFormat in
                prefs.updateLastFormat(newFormat)
                compressionLevel = prefs.compressionLevel(for: newFormat)
            }
        }
    }
    
    // MARK: - Compression Picker
    
    private var compressionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Compression Level")
                .font(.system(size: 12, weight: .medium))
            
            Picker("", selection: $compressionLevel) {
                ForEach(CompressionLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: compressionLevel) { _, newLevel in
                prefs.setCompressionLevel(newLevel, for: selectedFormat)
            }
        }
    }
    
    // MARK: - Password Section
    
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $usePassword) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Encrypt archive")
                        .font(.system(size: 13))
                }
            }
            .toggleStyle(.checkbox)
            
            if usePassword {
                HStack(spacing: 8) {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                
                // Save to Keychain option — togglable in dialog
                HStack(spacing: 4) {
                    Toggle(isOn: $prefs.useKeychainPasswords) {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                            Text("Remember password in Keychain")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: prefs.useKeychainPasswords) { _, newVal in
                        if newVal && !password.isEmpty {
                            ArchivePasswordStore.shared.savePassword(password)
                        } else if !newVal {
                            ArchivePasswordStore.shared.deletePassword()
                        }
                        prefs.save()
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.Button.select
        
        // Start from current custom destination or source panel
        let startPath = customDestination.isEmpty ? appState.path(for: sourcePanel) : customDestination
        if FileManager.default.fileExists(atPath: startPath) {
            panel.directoryURL = URL(fileURLWithPath: startPath)
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            customDestination = url.path
            destinationMode = .custom
            prefs.updateCustomDestination(url.path)
            prefs.updateDestinationMode(.custom)
        }
    }
    
    private func performPack() {
        let dest = resolvedDestination
        log.info("[PackDialog] \(#function) name='\(archiveName)' dest='\(dest.path)' format=\(selectedFormat) level=\(compressionLevel) encrypted=\(usePassword) deleteSource=\(deleteSourceFiles)")
        
        // Save password to Keychain if option enabled
        if usePassword && prefs.useKeychainPasswords && !password.isEmpty {
            ArchivePasswordStore.shared.savePassword(password)
        }
        
        let pwd: String? = usePassword && !password.isEmpty ? password : nil
        onPack(archiveName, selectedFormat, dest, deleteSourceFiles, compressionLevel, pwd)
    }
}

// MARK: - Preview

#Preview {
    PackDialog(
        mode: .pack,
        files: [CustomFile(path: "/Users/test/document.txt")],
        sourcePanel: .left,
        onPack: { _, _, _, _, _, _ in },
        onCancel: {}
    )
    .environment(AppState())
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

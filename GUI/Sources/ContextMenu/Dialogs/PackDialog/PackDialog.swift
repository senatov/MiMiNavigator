//  PackDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Updated by Claude on 18.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Enhanced pack dialog with destination selector, compression levels, passwords

import FileModelKit
import SwiftUI

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
    let sourcePanel: FavPanelSide
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

    @FocusState private var isNameFieldFocused: Bool

    // MARK: - Init

    init(
        mode: PackDialogMode = .pack,
        files: [CustomFile],
        sourcePanel: FavPanelSide,
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
        let savedDeleteSource = ArchivePreferencesStore.shared.deleteSourceFiles
        let savedUsePassword = ArchivePreferencesStore.shared.usePassword

        if mode == .compress {
            self._archiveName = State(initialValue: defaultName + "." + savedFormat.fileExtension)
        } else {
            self._archiveName = State(initialValue: defaultName)
        }
        self._selectedFormat = State(initialValue: savedFormat)
        self._destinationMode = State(initialValue: savedMode)
        self._customDestination = State(initialValue: savedCustom)
        self._compressionLevel = State(initialValue: savedLevel)
        self._deleteSourceFiles = State(initialValue: savedDeleteSource)
        self._usePassword = State(initialValue: savedUsePassword)
    }

    // MARK: - Computed Properties

    private var isValidName: Bool {
        !archiveName.isEmpty && !archiveName.contains("/") && !archiveName.contains(":")
    }

    private var sourcePath: String {
        appState.path(for: sourcePanel)
    }

    private var oppositePanel: FavPanelSide {
        sourcePanel == .left ? .right : .left
    }

    /// Resolved destination URL based on mode
    private var resolvedDestination: URL {
        switch destinationMode {
            case .currentPanel:
                return URL(fileURLWithPath: sourcePath)
            case .oppositePanel:
                return URL(fileURLWithPath: appState.path(for: oppositePanel))
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

    private var containsDirectoryInput: Bool {
        files.contains { $0.urlValue.hasDirectoryPath }
    }

    private var allowsSingleCompressedFormats: Bool {
        files.count == 1 && !containsDirectoryInput
    }

    private var selectableFormats: [ArchiveFormat] {
        let formats = ArchiveFormat.availableFormats
        guard !allowsSingleCompressedFormats else { return formats }
        return formats.filter { !$0.isSingleCompressedFile }
    }

    private static let knownArchiveExtensions: [String] = ArchiveFormat.allCases
        .map(\.fileExtension)
        .sorted { $0.count > $1.count }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PackArchiveNameField(
                label: L10n.Dialog.Pack.archiveNameLabel,
                placeholder: L10n.PathInput.nameLabel,
                text: $archiveName, hasError: !isValidName && !archiveName.isEmpty
            )
            .focused($isNameFieldFocused)

            PackDestinationSelector(
                destinationMode: $destinationMode,
                resolvedDestination: resolvedDestination,
                isValidDestination: isValidDestination,
                onBrowseForFolder: browseForFolder,
                onDestinationModeChange: { mode in
                    prefs.updateDestinationMode(mode)
                }
            )

            PackFormatPicker(
                selectedFormat: $selectedFormat,
                selectableFormats: selectableFormats,
                onFormatChange: { newFormat in
                    prefs.updateLastFormat(newFormat)
                    compressionLevel = prefs.compressionLevel(for: newFormat)
                    if mode == .compress {
                        syncArchiveNameWithSelectedFormat()
                    }
                }
            )

            if supportsCompression {
                PackCompressionPicker(
                    compressionLevel: $compressionLevel,
                    onCompressionChange: { newLevel in
                        prefs.setCompressionLevel(newLevel, for: selectedFormat)
                    }
                )
            }

            if supportsPassword {
                PackPasswordSection(
                    usePassword: $usePassword,
                    password: $password,
                    showPassword: $showPassword,
                    useKeychainPasswords: $prefs.useKeychainPasswords,
                    onUsePasswordChange: { prefs.updateUsePassword($0) },
                    onUseKeychainChange: { newValue in
                        if newValue && !password.isEmpty {
                            ArchivePasswordStore.shared.savePassword(password)
                        } else if !newValue {
                            ArchivePasswordStore.shared.deletePassword()
                        }
                        prefs.save()
                    }
                )
            }

            PackDeleteSourceToggle(
                mode: mode,
                deleteSourceFiles: $deleteSourceFiles,
                onChange: { prefs.updateDeleteSourceFiles($0) }
            )

            HIGDialogButtons(
                confirmTitle: confirmTitle,
                isConfirmDisabled: !isValidName || !isValidDestination,
                onCancel: onCancel,
                onConfirm: performPack
            )
        }
        .padding(16)
        .frame(minWidth: 400)
        .background(PackDialogStyle.panelBackground)
        .overlay(PackDialogStyle.panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: PackDialogStyle.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PackDialogStyle.outerCornerRadius, style: .continuous))
        .onAppear {
            if !selectableFormats.contains(selectedFormat),
               let fallback = selectableFormats.first {
                selectedFormat = fallback
                compressionLevel = prefs.compressionLevel(for: fallback)
            }
            isNameFieldFocused = true
            if mode == .compress {
                syncArchiveNameWithSelectedFormat()
            }
            // Load password from Keychain if enabled — but DON'T override encrypt flag
            if prefs.useKeychainPasswords, let saved = ArchivePasswordStore.shared.loadPassword() {
                password = saved
            }
        }
        .onKeyPress(.escape) { onCancel(); return .handled }
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
        let startPath = customDestination.isEmpty ? sourcePath : customDestination
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
        let normalizedName = normalizedArchiveNameForSubmit()
        if archiveName != normalizedName {
            archiveName = normalizedName
        }
        let dest = resolvedDestination
        log.info("[PackDialog] \(#function) name='\(normalizedName)' dest='\(dest.path)'")
        log.info("[PackDialog] format=\(selectedFormat) level=\(compressionLevel) encrypted=\(usePassword) deleteSource=\(deleteSourceFiles)")

        // persist all current dialog options for next session
        prefs.updateLastFormat(selectedFormat)
        prefs.setCompressionLevel(compressionLevel, for: selectedFormat)
        prefs.updateDestinationMode(destinationMode)
        prefs.updateDeleteSourceFiles(deleteSourceFiles)
        prefs.updateUsePassword(usePassword)
        if destinationMode == .custom {
            prefs.updateCustomDestination(customDestination)
        }

        // Save password to Keychain if option enabled
        if usePassword && prefs.useKeychainPasswords && !password.isEmpty {
            ArchivePasswordStore.shared.savePassword(password)
        }

        let pwd: String? = usePassword && !password.isEmpty ? password : nil
        onPack(normalizedName, selectedFormat, dest, deleteSourceFiles, compressionLevel, pwd)
    }

    private func syncArchiveNameWithSelectedFormat() {
        let baseName = baseArchiveName(from: archiveName)
        guard !baseName.isEmpty else { return }
        archiveName = "\(baseName).\(selectedFormat.fileExtension)"
    }

    private func normalizedArchiveNameForSubmit() -> String {
        let trimmed = archiveName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let baseName = baseArchiveName(from: trimmed)
        switch mode {
            case .compress:
                return "\(baseName).\(selectedFormat.fileExtension)"
            case .pack:
                return baseName
        }
    }

    private func baseArchiveName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lowercased = trimmed.lowercased()
        for ext in Self.knownArchiveExtensions {
            let suffix = ".\(ext.lowercased())"
            guard lowercased.hasSuffix(suffix) else { continue }
            return String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }
}

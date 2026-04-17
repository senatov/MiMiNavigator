// PackDialogSections.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

enum PackDialogStyle {
    static let outerCornerRadius: CGFloat = 14

    static var panelBackground: some View {
        RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
            .fill(.clear)
    }

    static var panelBorder: some View {
        RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }
}

struct PackArchiveNameField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let hasError: Bool

    var body: some View {
        HIGTextField(
            label: label,
            placeholder: placeholder,
            text: $text,
            hasError: hasError
        )
    }
}

struct PackDestinationSelector: View {
    @Binding var destinationMode: ArchivePreferencesStore.DestinationMode
    let resolvedDestination: URL
    let isValidDestination: Bool
    let onBrowseForFolder: () -> Void
    let onDestinationModeChange: (ArchivePreferencesStore.DestinationMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Dialog.Pack.saveToLabel)
                .font(.system(size: 12, weight: .medium))

            HStack(spacing: 8) {
                destinationButton(mode: .currentPanel, label: "Current", icon: "folder", shortcut: "1")
                destinationButton(mode: .oppositePanel, label: "Opposite", icon: "arrow.left.arrow.right", shortcut: "2")

                HStack(spacing: 4) {
                    destinationButton(mode: .custom, label: "Other…", icon: "folder.badge.gearshape", shortcut: "3")

                    if destinationMode == .custom {
                        Button(action: onBrowseForFolder) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }

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
                onDestinationModeChange(mode)
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
}

struct PackFormatPicker: View {
    @Binding var selectedFormat: ArchiveFormat
    let selectableFormats: [ArchiveFormat]
    let onFormatChange: (ArchiveFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Dialog.Pack.formatLabel)
                .font(.system(size: 12, weight: .medium))

            Picker("", selection: $selectedFormat) {
                ForEach(selectableFormats) { format in
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
                onFormatChange(newFormat)
            }
        }
    }
}

struct PackCompressionPicker: View {
    @Binding var compressionLevel: CompressionLevel
    let onCompressionChange: (CompressionLevel) -> Void

    var body: some View {
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
                onCompressionChange(newLevel)
            }
        }
    }
}

struct PackPasswordSection: View {
    @Binding var usePassword: Bool
    @Binding var password: String
    @Binding var showPassword: Bool
    @Binding var useKeychainPasswords: Bool
    let onUsePasswordChange: (Bool) -> Void
    let onUseKeychainChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $usePassword) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Encrypt archive")
                        .font(.system(size: 14))
                }
            }
            .toggleStyle(.checkbox)
            .onChange(of: usePassword) { _, newValue in
                onUsePasswordChange(newValue)
            }

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
                    .font(.system(size: 14))
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

                Toggle(isOn: $useKeychainPasswords) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10))
                        Text("Remember password in Keychain")
                            .font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
                .onChange(of: useKeychainPasswords) { _, newValue in
                    onUseKeychainChange(newValue)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct PackDeleteSourceToggle: View {
    let mode: PackDialogMode
    @Binding var deleteSourceFiles: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: $deleteSourceFiles) {
            Text(mode == .pack ? "Delete source files after packing" : "Move originals into archive")
                .font(.system(size: 14))
        }
        .toggleStyle(.checkbox)
        .onChange(of: deleteSourceFiles) { _, newValue in
            onChange(newValue)
        }
    }
}

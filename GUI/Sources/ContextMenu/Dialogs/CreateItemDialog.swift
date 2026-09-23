// CreateItemDialog.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared HIG-style dialog used to create files and folders.

import SwiftUI

// MARK: - Create Item Dialog Configuration
struct CreateItemDialogConfiguration {
    let title: String
    let defaultName: String
    let enterNameLabel: String
    let placeholder: String
    let emptyNameError: String
    let invalidNameError: String
    let systemImage: String
}

// MARK: - Create Item Dialog
struct CreateItemDialog: View {
    let parentURL: URL
    let configuration: CreateItemDialogConfiguration
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    @State private var itemName: String
    @State private var errorMessage: String?
    init(
        parentURL: URL,
        configuration: CreateItemDialogConfiguration,
        onCreate: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.parentURL = parentURL
        self.configuration = configuration
        self.onCreate = onCreate
        self.onCancel = onCancel
        self._itemName = State(initialValue: configuration.defaultName)
    }
    private var isValidName: Bool {
        let trimmed = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":/\\")) == nil
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HIGDialogHeader(configuration.title, subtitle: parentURL.path)
                .frame(maxWidth: .infinity)
            nameField
            if !itemName.isEmpty && !isValidName {
                Text(configuration.invalidNameError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            actionButtons
        }
        .higDialogStyle()
        .frame(minWidth: 380)
    }
    // MARK: - Name Field
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configuration.enterNameLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            HIGNameField(text: $itemName, placeholder: configuration.placeholder, onSubmit: performCreate)
                .frame(height: 19)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(nameFieldBorder)
        }
    }
    private var nameFieldBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(
                !isValidName && !itemName.isEmpty ? Color.red.opacity(0.7) : Color(nsColor: .separatorColor),
                lineWidth: 1
            )
    }
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Spacer()
            DownToolbarButtonView(title: L10n.Button.cancel, systemImage: "xmark", action: onCancel)
                .keyboardShortcut(.cancelAction)
            DownToolbarButtonView(title: L10n.Button.create, systemImage: configuration.systemImage, action: performCreate)
                .disabled(!isValidName)
                .opacity(isValidName ? 1 : 0.55)
        }
        .padding(.top, 6)
    }
    // MARK: - Perform Create
    private func performCreate() {
        let trimmed = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = configuration.emptyNameError
            return
        }
        guard isValidName else {
            errorMessage = configuration.invalidNameError
            return
        }
        onCreate(trimmed)
    }
}

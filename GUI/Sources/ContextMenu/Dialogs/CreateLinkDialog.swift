// CreateLinkDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Link Type
enum LinkType: String, CaseIterable, Identifiable, CustomStringConvertible {
    case symbolic
    case alias

    var id: String { rawValue }

    var description: String { displayName }

    var displayName: String {
        switch self {
            case .symbolic: return L10n.LinkType.symbolic
            case .alias: return L10n.LinkType.alias
        }
    }

    var hint: String {
        switch self {
            case .symbolic: return L10n.LinkType.symbolicDescription
            case .alias: return L10n.LinkType.aliasDescription
        }
    }
}

// MARK: - Create Link Dialog
struct CreateLinkDialog: View {
    let file: CustomFile
    let destinationPath: URL
    let onCreateLink: (String, LinkType) -> Void
    let onCancel: () -> Void

    @State private var linkName: String
    @State private var selectedType: LinkType = .symbolic
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    init(
        file: CustomFile,
        destinationPath: URL,
        onCreateLink: @escaping (String, LinkType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.file = file
        self.destinationPath = destinationPath
        self.onCreateLink = onCreateLink
        self.onCancel = onCancel
        self._linkName = State(initialValue: "\(file.nameStr) link")
    }

    private var isValidName: Bool {
        !linkName.isEmpty && !linkName.contains("/") && !linkName.contains(":")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header centered
            HIGDialogHeader(
                L10n.Dialog.CreateLink.title(file.nameStr),
                subtitle: L10n.Dialog.CreateLink.inLocation(destinationPath.path)
            )
            .frame(maxWidth: .infinity)

            // Link name field
            VStack(alignment: .leading, spacing: 6) {
                HIGTextField(
                    label: L10n.Dialog.CreateLink.linkNameLabel,
                    placeholder: L10n.PathInput.nameLabel,
                    text: $linkName,
                    hasError: errorMessage != nil
                )
                .focused($isTextFieldFocused)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }

            // Link type picker — .menu dropdown (like macOS Settings)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.CreateLink.typeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Picker("", selection: $selectedType) {
                    ForEach(LinkType.allCases) { type in
                        Text("\(type.displayName)  —  \(type.hint)").tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HIGDialogButtons(
                confirmTitle: L10n.Button.create,
                isConfirmDisabled: !isValidName,
                onCancel: onCancel,
                onConfirm: { onCreateLink(linkName, selectedType) }
            )
        }
        .higDialogStyle()
        .onAppear { isTextFieldFocused = true }
        .onChange(of: linkName) { _, newValue in validateName(newValue) }
    }

    private func validateName(_ name: String) {
        if name.isEmpty {
            errorMessage = L10n.Error.nameEmpty
        } else if name.contains("/") || name.contains(":") {
            errorMessage = L10n.Error.nameInvalidChars
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - Preview
#Preview {
    CreateLinkDialog(
        file: CustomFile(path: "/Users/test/document.txt"),
        destinationPath: URL(fileURLWithPath: "/Users/test"),
        onCreateLink: { _, _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

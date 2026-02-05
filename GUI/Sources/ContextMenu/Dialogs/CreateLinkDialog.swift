// CreateLinkDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Link Type
enum LinkType: String, CaseIterable, Identifiable {
    case symbolic
    case alias
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .symbolic: return L10n.LinkType.symbolic
        case .alias: return L10n.LinkType.alias
        }
    }
    
    var description: String {
        switch self {
        case .symbolic: return L10n.LinkType.symbolicDescription
        case .alias: return L10n.LinkType.aliasDescription
        }
    }
}

// MARK: - Create Link Dialog (HIG Style)
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
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            // Title
            Text(L10n.Dialog.CreateLink.title(file.nameStr))
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Destination info
            Text(L10n.Dialog.CreateLink.inLocation(destinationPath.path))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Link name
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.CreateLink.linkNameLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                TextField(L10n.PathInput.nameLabel, text: $linkName)
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
                            .stroke(errorMessage != nil ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                    .focused($isTextFieldFocused)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 280)
            
            // Link type picker
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Dialog.CreateLink.typeLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedType) {
                    ForEach(LinkType.allCases) { type in
                        Text("\(type.displayName) — \(type.description)")
                            .tag(type)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .frame(maxWidth: 280, alignment: .leading)
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: L10n.Button.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: L10n.Button.create, action: { onCreateLink(linkName, selectedType) })
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidName)
                    .opacity(isValidName ? 1.0 : 0.5)
            }
            .padding(.top, 4)
        }
        .higDialogStyle()
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: linkName) { _, newValue in
            validateName(newValue)
        }
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

// CreateLinkDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Link Type
enum LinkType: String, CaseIterable, Identifiable {
    case symbolic = "Symbolic Link"
    case alias = "Finder Alias"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .symbolic: return "Unix symlink, works in Terminal"
        case .alias: return "Finder alias, macOS apps only"
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
            Text("Create link to \"\(file.nameStr)\"")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Destination info
            Text("In: \(destinationPath.path)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Link name
            VStack(alignment: .leading, spacing: 4) {
                Text("Link name:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                TextField("Name", text: $linkName)
                    .textFieldStyle(.plain)
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
                Text("Type:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedType) {
                    ForEach(LinkType.allCases) { type in
                        Text("\(type.rawValue) — \(type.description)")
                            .tag(type)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .frame(maxWidth: 280, alignment: .leading)
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: "Create", action: { onCreateLink(linkName, selectedType) })
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
            errorMessage = "Name cannot be empty"
        } else if name.contains("/") || name.contains(":") {
            errorMessage = "Name cannot contain / or :"
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

// RenameDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Rename Dialog (HIG Style)
struct RenameDialog: View {
    let file: CustomFile
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newName: String
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    init(file: CustomFile, onRename: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.file = file
        self.onRename = onRename
        self.onCancel = onCancel
        self._newName = State(initialValue: file.nameStr)
    }
    
    private var isValidName: Bool {
        !newName.isEmpty && 
        !newName.contains("/") && 
        !newName.contains(":") &&
        newName != "." &&
        newName != ".."
    }
    
    private var hasChanges: Bool {
        newName != file.nameStr
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            // Title
            Text("Rename \(file.isDirectory ? "folder" : "file")")
                .font(.system(size: 13, weight: .semibold))
            
            // Current location
            Text(file.urlValue.deletingLastPathComponent().path)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Text field
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $newName)
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
                            .stroke(errorMessage != nil ? Color.red : Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if isValidName && hasChanges {
                            onRename(newName)
                        }
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 280)
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: "Rename", action: { onRename(newName) })
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidName || !hasChanges)
                    .opacity(isValidName && hasChanges ? 1.0 : 0.5)
            }
            .padding(.top, 4)
        }
        .higDialogStyle()
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: newName) { _, newValue in
            validateName(newValue)
        }
    }
    
    private func validateName(_ name: String) {
        if name.isEmpty {
            errorMessage = "Name cannot be empty"
        } else if name.contains("/") || name.contains(":") {
            errorMessage = "Name cannot contain / or :"
        } else if name == "." || name == ".." {
            errorMessage = "Invalid name"
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - Preview
#Preview {
    RenameDialog(
        file: CustomFile(path: "/Users/test/document.txt"),
        onRename: { _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

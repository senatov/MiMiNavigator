// RenameDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Rename Dialog
struct RenameDialog: View {
    let file: CustomFile
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newName: String
    @State private var errorMessage: String?
    @State private var isHoveringRename = false
    @State private var isHoveringCancel = false
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
        VStack(spacing: 20) {
            // Icon
            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(file.isDirectory ? .blue : .gray)
                .padding(.top, 8)
            
            // Title
            Text("Rename")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Current name info
            Text("Current name: \(file.nameStr)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Text field
            VStack(alignment: .leading, spacing: 6) {
                TextField("New name", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if isValidName && hasChanges {
                            onRename(newName)
                        }
                    }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 16) {
                // Cancel button
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Cancel")
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringCancel ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCancel = $0 }
                .keyboardShortcut(.cancelAction)
                
                // Rename button
                Button(action: { onRename(newName) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle")
                        Text("Rename")
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isValidName && hasChanges
                                ? (isHoveringRename ? Color.blue.opacity(0.9) : Color.blue.opacity(0.8))
                                : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringRename = $0 }
                .disabled(!isValidName || !hasChanges)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(minWidth: 400, maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            isTextFieldFocused = true
            // Select filename without extension
            selectFilenameWithoutExtension()
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
    
    private func selectFilenameWithoutExtension() {
        // This would require NSTextView access for selection
        // For SwiftUI TextField, we just focus it
    }
}

// MARK: - Preview
#Preview {
    RenameDialog(
        file: CustomFile(url: URL(fileURLWithPath: "/test/document.txt")),
        onRename: { _ in },
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

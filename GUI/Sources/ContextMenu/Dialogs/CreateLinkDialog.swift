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
    
    var icon: String {
        switch self {
        case .symbolic: return "link"
        case .alias: return "link.badge.plus"
        }
    }
    
    var description: String {
        switch self {
        case .symbolic: 
            return "Unix symbolic link. Works in Terminal and most apps."
        case .alias: 
            return "Finder alias. Only works in Finder and some macOS apps."
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
    @State private var isHoveringCreate = false
    @State private var isHoveringCancel = false
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
        !linkName.isEmpty &&
        !linkName.contains("/") &&
        !linkName.contains(":")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.top, 8)
            
            // Title
            Text("Create Link")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Source info
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                Text("To: \(file.nameStr)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // Link name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Link name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Link name", text: $linkName)
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
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            
            // Link type selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Link type:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(LinkType.allCases) { type in
                    LinkTypeRow(
                        type: type,
                        isSelected: selectedType == type,
                        onSelect: { selectedType = type }
                    )
                }
            }
            
            // Destination info
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text("In: \(destinationPath.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
                
                // Create button
                Button(action: { onCreateLink(linkName, selectedType) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("Create")
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isValidName
                                ? (isHoveringCreate ? Color.blue.opacity(0.9) : Color.blue.opacity(0.8))
                                : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCreate = $0 }
                .disabled(!isValidName)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: 520)
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

// MARK: - Link Type Row
private struct LinkTypeRow: View {
    let type: LinkType
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.system(size: 18))
                
                // Type icon
                Image(systemName: type.icon)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 20)
                
                // Type info
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected 
                        ? Color.blue.opacity(0.1) 
                        : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    CreateLinkDialog(
        file: CustomFile(path: "/test/document.txt"),
        destinationPath: URL(fileURLWithPath: "/Users/test"),
        onCreateLink: { _, _ in },
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

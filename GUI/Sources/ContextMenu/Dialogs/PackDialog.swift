// PackDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Pack Dialog
struct PackDialog: View {
    let files: [CustomFile]
    let destinationPath: URL
    let onPack: (String, ArchiveFormat) -> Void
    let onCancel: () -> Void
    
    @State private var archiveName: String
    @State private var selectedFormat: ArchiveFormat = .zip
    @State private var errorMessage: String?
    @State private var isHoveringPack = false
    @State private var isHoveringCancel = false
    @FocusState private var isTextFieldFocused: Bool
    
    init(
        files: [CustomFile],
        destinationPath: URL,
        onPack: @escaping (String, ArchiveFormat) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.files = files
        self.destinationPath = destinationPath
        self.onPack = onPack
        self.onCancel = onCancel
        
        // Default archive name
        let defaultName: String
        if files.count == 1 {
            defaultName = files[0].urlValue.deletingPathExtension().lastPathComponent
        } else {
            defaultName = "Archive"
        }
        self._archiveName = State(initialValue: defaultName)
    }
    
    private var isValidName: Bool {
        !archiveName.isEmpty &&
        !archiveName.contains("/") &&
        !archiveName.contains(":")
    }
    
    private var itemsDescription: String {
        if files.count == 1 {
            return files[0].nameStr
        } else {
            return "\(files.count) items"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "archivebox.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .padding(.top, 8)
            
            // Title
            Text("Create Archive")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Items info
            Text("Pack: \(itemsDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Archive name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Archive name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Archive name", text: $archiveName)
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
            
            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Archive format:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(ArchiveFormat.availableFormats) { format in
                    FormatRow(
                        format: format,
                        isSelected: selectedFormat == format,
                        onSelect: { selectedFormat = format }
                    )
                }
            }
            
            // Destination info
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text("To: \(destinationPath.path)")
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
                
                // Pack button
                Button(action: { onPack(archiveName, selectedFormat) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "archivebox")
                        Text("Pack")
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isValidName
                                ? (isHoveringPack ? Color.orange.opacity(0.9) : Color.orange.opacity(0.8))
                                : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringPack = $0 }
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
        .onChange(of: archiveName) { _, newValue in
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

// MARK: - Format Row
private struct FormatRow: View {
    let format: ArchiveFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .orange : .gray)
                    .font(.system(size: 18))
                
                // Format icon
                Image(systemName: format.icon)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .frame(width: 20)
                
                // Format info
                VStack(alignment: .leading, spacing: 2) {
                    Text(".\(format.fileExtension)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    Text(format.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected 
                        ? Color.orange.opacity(0.1) 
                        : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    PackDialog(
        files: [],
        destinationPath: URL(fileURLWithPath: "/Users/test"),
        onPack: { _, _ in },
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

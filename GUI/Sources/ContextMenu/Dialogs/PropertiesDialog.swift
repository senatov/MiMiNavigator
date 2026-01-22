// PropertiesDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Properties Dialog
struct PropertiesDialog: View {
    let file: CustomFile
    let onClose: () -> Void
    
    @State private var properties: FileProperties?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with icon and name
            headerSection
            
            Divider()
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if let props = properties {
                propertiesContent(props)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Divider()
            
            // Close button
            Button(action: onClose) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Close")
                }
                .frame(minWidth: 100)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringClose ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
            .keyboardShortcut(.cancelAction)
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
        .task {
            await loadProperties()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 16) {
            // File icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.nameStr)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(file.isDirectory ? "Folder" : file.fileExtension.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Properties Content
    @ViewBuilder
    private func propertiesContent(_ props: FileProperties) -> some View {
        VStack(spacing: 12) {
            // General section
            GroupBox("General") {
                VStack(spacing: 8) {
                    propertyRow("Kind:", props.isDirectory ? "Folder" : "File")
                    propertyRow("Size:", props.formattedSize)
                    if props.isDirectory && props.itemCount > 0 {
                        propertyRow("Contains:", "\(props.itemCount) items")
                    }
                }
                .padding(8)
            }
            
            // Location section
            GroupBox("Location") {
                VStack(spacing: 8) {
                    propertyRow("Path:", props.path, selectable: true)
                }
                .padding(8)
            }
            
            // Dates section
            GroupBox("Dates") {
                VStack(spacing: 8) {
                    if let created = props.created {
                        propertyRow("Created:", formatDate(created))
                    }
                    if let modified = props.modified {
                        propertyRow("Modified:", formatDate(modified))
                    }
                }
                .padding(8)
            }
            
            // Permissions section
            GroupBox("Permissions") {
                VStack(spacing: 8) {
                    propertyRow("Readable:", props.isReadable ? "Yes" : "No")
                    propertyRow("Writable:", props.isWritable ? "Yes" : "No")
                    propertyRow("Executable:", props.isExecutable ? "Yes" : "No")
                    if let perms = props.permissions {
                        propertyRow("POSIX:", String(format: "%o", perms))
                    }
                }
                .padding(8)
            }
            
            // Symlink info
            if props.isSymlink {
                GroupBox("Symlink") {
                    VStack(spacing: 8) {
                        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: props.path) {
                            propertyRow("Target:", target, selectable: true)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
    
    // MARK: - Property Row
    @ViewBuilder
    private func propertyRow(_ label: String, _ value: String, selectable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            if selectable {
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
                    .lineLimit(3)
            } else {
                Text(value)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Load Properties
    private func loadProperties() async {
        do {
            properties = try FileOperationsService.shared.getProperties(for: file.urlValue)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Format Date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    PropertiesDialog(
        file: CustomFile(path: "/Users"),
        onClose: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

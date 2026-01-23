// PropertiesDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Properties Dialog (HIG Style)
struct PropertiesDialog: View {
    let file: CustomFile
    let onClose: () -> Void
    
    @State private var properties: FileProperties?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // File icon (large, from system)
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 64, height: 64)
            
            // File name
            Text(file.nameStr)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding()
            } else if let props = properties {
                propertiesContent(props)
            } else if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            
            // Close button
            HIGPrimaryButton(title: "OK", action: onClose)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .higDialogStyle()
        .frame(minWidth: 300)
        .task {
            await loadProperties()
        }
    }
    
    @ViewBuilder
    private func propertiesContent(_ props: FileProperties) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            propertyRow("Kind:", props.isDirectory ? "Folder" : file.fileExtension.uppercased())
            propertyRow("Size:", props.formattedSize)
            
            if props.isDirectory && props.itemCount > 0 {
                propertyRow("Contains:", "\(props.itemCount) items")
            }
            
            Divider()
            
            propertyRow("Location:", props.url.deletingLastPathComponent().path)
            
            if let created = props.created {
                propertyRow("Created:", formatDate(created))
            }
            if let modified = props.modified {
                propertyRow("Modified:", formatDate(modified))
            }
            
            Divider()
            
            HStack(spacing: 16) {
                permissionBadge("R", props.isReadable)
                permissionBadge("W", props.isWritable)
                permissionBadge("X", props.isExecutable)
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: 11))
    }
    
    @ViewBuilder
    private func propertyRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func permissionBadge(_ letter: String, _ enabled: Bool) -> some View {
        Text(letter)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(enabled ? .white : .secondary)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(enabled ? Color.green : Color.gray.opacity(0.3))
            )
    }
    
    private func loadProperties() async {
        do {
            properties = try FileOperationsService.shared.getProperties(for: file.urlValue)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    PropertiesDialog(
        file: CustomFile(path: "/Users"),
        onClose: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

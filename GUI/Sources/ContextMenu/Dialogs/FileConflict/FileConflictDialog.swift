// FileConflictDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main dialog view for resolving file naming conflicts (HIG Style)

import SwiftUI

// MARK: - File Conflict Dialog
/// macOS HIG-compliant dialog for handling file copy/move conflicts
struct FileConflictDialog: View {
    let conflict: FileConflictInfo
    let onResolve: (ConflictResolution) -> Void
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
            Divider()
            buttonSection
        }
        .frame(width: 480)
        .background(dialogBackground)
        .overlay(dialogBorder)
    }
}

// MARK: - View Components
private extension FileConflictDialog {
    var headerSection: some View {
        HStack {
            Text("[ File Name ] Conflict")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DialogColors.stripe)
    }
    
    var contentSection: some View {
        VStack(spacing: 16) {
            FileInfoRow(
                title: "Copying",
                url: conflict.sourceURL,
                name: conflict.sourceName,
                size: conflict.sourceSize,
                date: conflict.sourceDate
            )
            
            Divider()
                .padding(.horizontal)
            
            FileInfoRow(
                title: "Existing Target",
                url: conflict.targetURL,
                name: conflict.targetName,
                size: conflict.targetSize,
                date: conflict.targetDate
            )
        }
        .padding(16)
    }
    
    var buttonSection: some View {
        HStack(spacing: 8) {
            Spacer()
            ConflictButton(title: "Skip", action: { onResolve(.skip) })
            ConflictButton(title: "Keep Both", isPrimary: true, action: { onResolve(.keepBoth) })
            ConflictButton(title: "Stop", action: { onResolve(.stop) })
            ConflictButton(title: "Replace", action: { onResolve(.replace) })
        }
        .padding(12)
        .background(DialogColors.stripe)
    }
}

// MARK: - Styling
private extension FileConflictDialog {
    var dialogBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DialogColors.base)
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
    
    var dialogBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
    }
}

// MARK: - Preview
#Preview {
    FileConflictDialog(
        conflict: FileConflictInfo(
            source: URL(fileURLWithPath: "/Users/senat/Downloads/test.mp4"),
            target: URL(fileURLWithPath: "/private/tmp/test.mp4")
        ),
        onResolve: { _ in }
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

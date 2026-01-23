// ConfirmationDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - macOS HIG Style Dialog Base
struct HIGDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(minWidth: 300, maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
    }
}

extension View {
    func higDialogStyle() -> some View {
        modifier(HIGDialogStyle())
    }
}

// MARK: - HIG Button Style
struct HIGPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white)
                .frame(minWidth: 70)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDestructive 
                            ? (isHovering ? Color.red.opacity(0.9) : Color.red.opacity(0.8))
                            : (isHovering ? Color.accentColor.opacity(0.9) : Color.accentColor))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct HIGSecondaryButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .frame(minWidth: 70)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Delete Confirmation Dialog (HIG Style)
struct DeleteConfirmationDialog: View {
    let files: [CustomFile]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    private var itemsDescription: String {
        if files.count == 1 {
            return "\"\(files[0].nameStr)\""
        } else {
            return "\(files.count) items"
        }
    }
    
    private var isDirectory: Bool {
        files.count == 1 && files[0].isDirectory
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            // Title
            Text("Do you want to move \(itemsDescription) to Trash?")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle with path
            if files.count == 1 {
                Text(files[0].urlValue.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: "Move to Trash", action: onConfirm, isDestructive: true)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .higDialogStyle()
    }
}

// MARK: - Generic Confirmation Dialog
struct GenericConfirmationDialog: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    init(
        title: String,
        message: String? = nil,
        confirmTitle: String = "OK",
        cancelTitle: String = "Cancel",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            // Title
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Message
            if let message = message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: cancelTitle, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                HIGPrimaryButton(title: confirmTitle, action: onConfirm, isDestructive: isDestructive)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .higDialogStyle()
    }
}

// MARK: - Preview
#Preview("Delete Single File") {
    DeleteConfirmationDialog(
        files: [CustomFile(path: "/Users/test/document.txt")],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Delete Multiple") {
    DeleteConfirmationDialog(
        files: [
            CustomFile(path: "/Users/test/file1.txt"),
            CustomFile(path: "/Users/test/file2.txt")
        ],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Generic") {
    GenericConfirmationDialog(
        title: "Do you want to duplicate items here?",
        message: "/Users/senat/Downloads/Musor",
        confirmTitle: "OK",
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

// ConfirmationDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Confirmation Dialog Style
enum ConfirmationStyle {
    case warning
    case danger
    case info
    
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "trash.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .warning: return .orange
        case .danger: return .red
        case .info: return .blue
        }
    }
}

// MARK: - Confirmation Dialog View
struct ConfirmationDialog: View {
    let title: String
    let message: String
    let style: ConfirmationStyle
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isHoveringConfirm = false
    @State private var isHoveringCancel = false
    
    init(
        title: String,
        message: String,
        style: ConfirmationStyle = .warning,
        confirmTitle: String = "Yes",
        cancelTitle: String = "No",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: style.iconName)
                .font(.system(size: 48))
                .foregroundStyle(style.iconColor)
                .padding(.top, 8)
            
            // Title
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 16) {
                // Cancel button
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text(cancelTitle)
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
                
                // Confirm button
                Button(action: onConfirm) {
                    HStack(spacing: 6) {
                        Image(systemName: style == .danger ? "trash" : "checkmark.circle")
                        Text(confirmTitle)
                    }
                    .frame(minWidth: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringConfirm 
                                ? style.iconColor.opacity(0.9) 
                                : style.iconColor.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringConfirm = $0 }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(minWidth: 350, maxWidth: 450)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Delete Confirmation Dialog
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
    
    var body: some View {
        ConfirmationDialog(
            title: "Move to Trash?",
            message: "Are you sure you want to move \(itemsDescription) to Trash?",
            style: .danger,
            confirmTitle: "Move to Trash",
            cancelTitle: "Cancel",
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
}

// MARK: - Preview
#Preview("Warning") {
    ConfirmationDialog(
        title: "Confirm Operation",
        message: "Are you sure you want to proceed with this operation?",
        style: .warning,
        onConfirm: {},
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Delete") {
    DeleteConfirmationDialog(
        files: [],
        onConfirm: {},
        onCancel: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

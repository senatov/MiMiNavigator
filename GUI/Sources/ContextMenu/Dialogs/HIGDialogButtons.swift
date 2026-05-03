// HIGDialogButtons.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Standard HIG button row: Cancel (Esc) left, primary action (Enter) right.

import SwiftUI

// MARK: - HIGDialogButtons
struct HIGDialogButtons: View {
    let cancelTitle: String
    let confirmTitle: String
    let isDestructive: Bool
    let isConfirmDisabled: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    init(
        cancelTitle: String = "Cancel",
        confirmTitle: String,
        isDestructive: Bool = false,
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.isConfirmDisabled = isConfirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    var body: some View {
        HStack(spacing: 10) {
            Button(cancelTitle, action: onCancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.large)
                .focusable(true)
            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ThemedButtonStyle())
                .tint(isDestructive ? .red : .accentColor)
                .controlSize(.large)
                .focusable(true)
                .disabled(isConfirmDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 6)
    }
}

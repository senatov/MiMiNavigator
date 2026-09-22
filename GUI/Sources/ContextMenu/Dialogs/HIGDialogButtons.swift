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
    let cancelSystemImage: String
    let confirmSystemImage: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    init(
        cancelTitle: String = "Cancel",
        confirmTitle: String,
        isDestructive: Bool = false,
        isConfirmDisabled: Bool = false,
        cancelSystemImage: String = "xmark",
        confirmSystemImage: String = "checkmark",
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.isConfirmDisabled = isConfirmDisabled
        self.cancelSystemImage = cancelSystemImage
        self.confirmSystemImage = confirmSystemImage
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    var body: some View {
        DialogFooter {
            DownToolbarButtonView(title: cancelTitle, systemImage: cancelSystemImage, action: onCancel)
                .keyboardShortcut(.cancelAction)
            DownToolbarButtonView(title: confirmTitle, systemImage: confirmSystemImage, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .disabled(isConfirmDisabled)
        }
    }
}

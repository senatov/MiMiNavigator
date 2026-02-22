// ArchivePasswordDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 18.02.2026 — HIGTextField, HIGDialogButtons, native focus ring
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dialog for requesting password for encrypted archives during search

import SwiftUI

// MARK: - Archive Password Dialog
struct ArchivePasswordDialog: View {
    let archiveName: String
    @Binding var password: String
    let onSubmit: () -> Void
    let onSkip: () -> Void

    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "lock.doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                Text("Password Required")
                    .font(.system(size: 14, weight: .semibold))

                VStack(spacing: 2) {
                    Text("The archive is password-protected:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(archiveName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity)

            // Password field
            HIGTextField(
                label: "Password",
                placeholder: "Enter password…",
                text: $password,
                isSecure: true
            )
            .focused($isPasswordFocused)
            .onSubmit {
                if !password.isEmpty { onSubmit() }
            }

            HIGDialogButtons(
                cancelTitle: "Skip Archive",
                confirmTitle: "OK",
                isConfirmDisabled: password.isEmpty,
                onCancel: onSkip,
                onConfirm: onSubmit
            )
        }
        .padding(24)
        .frame(width: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
        .onAppear { isPasswordFocused = true }
    }
}

// MARK: - Preview
#Preview {
    ArchivePasswordDialog(
        archiveName: "secret_docs.7z",
        password: .constant(""),
        onSubmit: {},
        onSkip: {}
    )
}

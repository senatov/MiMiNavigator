// ArchivePasswordDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
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
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "lock.doc")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            // Title
            Text("Password Required")
                .font(.system(size: 14, weight: .semibold))

            // Archive name
            Text("The archive is password-protected:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(archiveName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.horizontal, 8)

            // Password field
            SecureField("Enter password…", text: $password)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 260)
                .focused($isPasswordFocused)
                .onSubmit {
                    if !password.isEmpty {
                        onSubmit()
                    }
                }

            // Buttons
            HStack(spacing: 12) {
                HIGSecondaryButton(title: "Skip Archive", action: onSkip)

                HIGPrimaryButton(title: "OK", action: onSubmit)
                    .disabled(password.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isPasswordFocused = true
        }
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

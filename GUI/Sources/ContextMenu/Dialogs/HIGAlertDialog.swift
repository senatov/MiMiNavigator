// HIGAlertDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: HIG-style alert dialog for error and success messages

import SwiftUI

// MARK: - HIG Alert Dialog
/// Reusable alert dialog with app icon badge, title, message and dismiss button.
/// Used for error/success feedback after file operations.
struct HIGAlertDialog: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            iconBadge
            titleText
            messageText
            dismissButton
        }
        .higDialogStyle()
    }

    // MARK: - Icon Badge
    private var iconBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
                .background(
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 28, height: 28)
                )
                .offset(x: 4, y: 4)
        }
    }

    // MARK: - Title
    private var titleText: some View {
        Text(title)
            .font(.system(size: 13, weight: .light))
            .multilineTextAlignment(.center)
    }

    // MARK: - Message
    private var messageText: some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(4)
    }

    // MARK: - Dismiss Button
    private var dismissButton: some View {
        HIGPrimaryButton(title: "OK", action: onDismiss)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
    }
}

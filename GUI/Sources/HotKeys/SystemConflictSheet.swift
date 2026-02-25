// SystemConflictSheet.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 25.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal sheet shown when user tries to assign a shortcut
//   that conflicts with macOS system shortcuts. Shows conflict details
//   and up to 3 safe alternative shortcuts as clickable buttons.

import SwiftUI

// MARK: - System Conflict Info
struct SystemConflictInfo {
    let action: HotKeyAction
    let description: String
    let suggestions: [(keyCode: UInt16, modifiers: HotKeyModifiers, display: String)]
}

// MARK: - System Conflict Sheet
struct SystemConflictSheet: View {
    let info: SystemConflictInfo
    let onSelect: (UInt16, HotKeyModifiers) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Shortcut Conflict")
                    .font(.system(size: 16, weight: .semibold))

                Text(info.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                Text("for '\(info.action.displayName)'")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Suggestions
            if !info.suggestions.isEmpty {
                VStack(spacing: 4) {
                    Text("Safe alternatives:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)

                    ForEach(Array(info.suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button {
                            onSelect(suggestion.keyCode, suggestion.modifiers)
                        } label: {
                            HStack(spacing: 8) {
                                Text(suggestion.display)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 12)
            } else {
                Text("No safe alternatives found.\nTry a different key combination.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 360)
        .background(DialogColors.base)
    }
}

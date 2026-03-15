// HIGTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Labeled input section matching GitHub Desktop / macOS Settings style.

import SwiftUI

// MARK: - HIGTextField
/// White fill, 1pt border, 6pt radius.
struct HIGTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false
    var isSecure: Bool = false
    var focusState: FocusState<Bool>.Binding? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textContentType(.none)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        hasError ? Color.red.opacity(0.7) : Color(nsColor: .separatorColor),
                        lineWidth: 1
                    )
            )
        }
    }
}

// DialogTextInputAppearance.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: User-configurable placeholder and field-label appearance for dialogs.

import AppKit
import SwiftUI

// MARK: - Dialog Text Input Appearance
enum DialogTextInputAppearance {
    static let placeholderColorKey = "dialog.input.placeholderColor"
    static let placeholderOpacityKey = "dialog.input.placeholderOpacity"
    static let labelColorKey = "dialog.input.labelColor"
    static let defaultPlaceholderHex = "424242"
    static let defaultLabelHex = "173F6B"
    static let defaultPlaceholderOpacity = 0.55
}

// MARK: - Dialog Text Field
struct DialogTextField: View {
    let placeholder: String
    @Binding var text: String
    @AppStorage(DialogTextInputAppearance.placeholderColorKey)
    private var placeholderHex = DialogTextInputAppearance.defaultPlaceholderHex
    @AppStorage(DialogTextInputAppearance.placeholderOpacityKey)
    private var placeholderOpacity = DialogTextInputAppearance.defaultPlaceholderOpacity
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .italic()
                .foregroundColor(placeholderColor.opacity(placeholderOpacity))
        )
        .foregroundStyle(Color(nsColor: .textColor))
    }
    private var placeholderColor: Color {
        Color(hex: placeholderHex)
            ?? Color(#colorLiteral(red: 0.19, green: 0.36, blue: 0.51, alpha: 1))
    }
}

// MARK: - Dialog Secure Field
struct DialogSecureField: View {
    let placeholder: String
    @Binding var text: String
    @AppStorage(DialogTextInputAppearance.placeholderColorKey)
    private var placeholderHex = DialogTextInputAppearance.defaultPlaceholderHex
    @AppStorage(DialogTextInputAppearance.placeholderOpacityKey)
    private var placeholderOpacity = DialogTextInputAppearance.defaultPlaceholderOpacity
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    var body: some View {
        SecureField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .italic()
                .foregroundColor(placeholderColor.opacity(placeholderOpacity))
        )
        .foregroundStyle(Color(nsColor: .textColor))
    }
    private var placeholderColor: Color {
        Color(hex: placeholderHex)
            ?? Color(#colorLiteral(red: 0.19, green: 0.36, blue: 0.51, alpha: 1))
    }
}

// MARK: - View Extension
extension View {
    func dialogFieldLabelStyle(size: CGFloat = 14) -> some View {
        modifier(DialogFieldLabelStyleModifier(size: size))
    }
}

// MARK: - Dialog Field Label Style Modifier
private struct DialogFieldLabelStyleModifier: ViewModifier {
    let size: CGFloat
    @AppStorage(DialogTextInputAppearance.labelColorKey)
    private var labelHex = DialogTextInputAppearance.defaultLabelHex
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundStyle(
                Color(hex: labelHex) ?? Color(#colorLiteral(red: 0.09, green: 0.25, blue: 0.42, alpha: 1))
            )
    }
}

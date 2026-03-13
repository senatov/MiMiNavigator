//  HIGComponents.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - HIGDialogStyle
/// Consistent panel styling for all modal dialogs.
/// Uses Word-Einstellungen gray palette: base #EFEFEF background, 12pt radius.
struct HIGDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .frame(minWidth: 320, maxWidth: 440)
            .background(DialogColors.base)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}
extension View {
    func higDialogStyle() -> some View {
        modifier(HIGDialogStyle())
    }
}

// MARK: - HIGTextField
/// Renders a labeled input section matching GitHub Desktop / macOS Settings style.
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

// MARK: - HIGPicker
/// Matches macOS Settings "External Editor" / "Shell" picker — .menu style.
struct HIGPicker<T: Hashable & CustomStringConvertible, Content: View>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    var displayName: (T) -> String = { $0.description }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(displayName(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - HIGDialogButtons
/// Standard HIG button row: Cancel (Esc) left, primary action (Enter) right.
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
            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ThemedButtonStyle())
                .tint(isDestructive ? .red : .accentColor)
                .controlSize(.large)
                .disabled(isConfirmDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 6)
    }
}

// MARK: - HIGDialogHeader
/// Standard macOS app icon + bold title block used in all alert-style dialogs.
struct HIGDialogHeader: View {
    let title: String
    let subtitle: String?
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Legacy Button Aliases
typealias HIGPrimaryButton = _LegacyHIGPrimaryButton
typealias HIGSecondaryButton = _LegacyHIGSecondaryButton
// MARK: - _LegacyHIGPrimaryButton
struct _LegacyHIGPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false
    var body: some View {
        Button(title, action: action)
            .buttonStyle(ThemedButtonStyle())
            .tint(isDestructive ? .red : .accentColor)
            .controlSize(.large)
    }
}
// MARK: - _LegacyHIGSecondaryButton
struct _LegacyHIGSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.large)
    }
}

// MARK: - HIGAutoFocusTextField
/// Forces AppKit first responder to the first editable NSTextField
/// inside a SwiftUI overlay dialog.
struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            Task { @MainActor in
                guard let window = NSApp.keyWindow else { return }
                Self.focusFirstTextField(in: window.contentView)
            }
        }
    }
    private static func focusFirstTextField(in view: NSView?) {
        guard let view else { return }
        if let tf = view as? NSTextField, tf.isEditable {
            tf.window?.makeFirstResponder(tf)
            tf.selectText(nil)
            return
        }
        for sub in view.subviews {
            focusFirstTextField(in: sub)
        }
    }
}
extension View {
    /// Apply to any dialog that contains a HIGTextField to auto-focus it on appear.
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}

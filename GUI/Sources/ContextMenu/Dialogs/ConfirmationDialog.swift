// ConfirmationDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI
import FileModelKit

// MARK: - macOS Word-Einstellungen style gray palette
/// Three static gray tones matching macOS Settings / Word-Einstellungen dialogs:
///   dialogLight  #F7F7F7 — section headers, card backgrounds
///   dialogBase   #EFEFEF — main dialog background
///   dialogStripe #E7E7E7 — contrast stripes, divider areas
enum DialogColors {
    static let light = Color(red: 247 / 255, green: 247 / 255, blue: 247 / 255)
    static let base = Color(red: 239 / 255, green: 239 / 255, blue: 239 / 255)
    static let stripe = Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)
}

// MARK: - macOS HIG 26 Dialog Base Modifier
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
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

extension View {
    func higDialogStyle() -> some View {
        modifier(HIGDialogStyle())
    }
}

// MARK: - HIG Input Field Style
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

// MARK: - HIG Dropdown (Picker) Style
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

// MARK: - Dialog Button Row
/// Standard HIG button row: Cancel (Esc) left, primary action (Enter) right.
/// Uses native SwiftUI .bordered / .borderedProminent — system handles focus ring automatically.
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
                .keyboardShortcut(.cancelAction)  // Esc
                .buttonStyle(.bordered)
                .controlSize(.large)

            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)  // Enter — system draws blue ring
                .buttonStyle(isDestructive ? .borderedProminent : .borderedProminent)
                .tint(isDestructive ? .red : .accentColor)
                .controlSize(.large)
                .disabled(isConfirmDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 6)
    }
}

// MARK: - Dialog Icon + Title Block
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

// MARK: - Legacy Button Aliases (backward compat — prefer HIGDialogButtons)
typealias HIGPrimaryButton = _LegacyHIGPrimaryButton
typealias HIGSecondaryButton = _LegacyHIGSecondaryButton

struct _LegacyHIGPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(isDestructive ? .red : .accentColor)
            .controlSize(.large)
    }
}

struct _LegacyHIGSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.large)
    }
}

// MARK: - Delete Confirmation Dialog
struct DeleteConfirmationDialog: View {
    let files: [CustomFile]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var itemsDescription: String {
        files.count == 1 ? "\"\(files[0].nameStr)\"" : "\(files.count) items"
    }

    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(
                "Do you want to move \(itemsDescription) to Trash?",
                subtitle: files.count == 1 ? files[0].urlValue.deletingLastPathComponent().path : nil
            )

            HIGDialogButtons(
                confirmTitle: "Move to Trash",
                isDestructive: true,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .higDialogStyle()
    }
}

// MARK: - Generic Confirmation Dialog
struct GenericConfirmationDialog: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String? = nil,
        confirmTitle: String = "OK",
        cancelTitle: String = "Cancel",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(title, subtitle: message)

            HIGDialogButtons(
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                isDestructive: isDestructive,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
        .higDialogStyle()
    }
}

// MARK: - Previews
#Preview("Delete Single File") {
    DeleteConfirmationDialog(
        files: [CustomFile(path: "/Users/test/document.txt")],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Delete Multiple") {
    DeleteConfirmationDialog(
        files: [
            CustomFile(path: "/Users/test/file1.txt"),
            CustomFile(path: "/Users/test/file2.txt"),
        ],
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Generic") {
    GenericConfirmationDialog(
        title: "Do you want to duplicate items here?",
        message: "/Users/senat/Downloads/Musor",
        confirmTitle: "OK",
        onConfirm: {},
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

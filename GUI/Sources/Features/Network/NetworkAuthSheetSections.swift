// NetworkAuthSheetSections.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

enum NetworkAuthSheetLayout {
    static let dialogWidth: CGFloat = 380
    static let cornerRadius: CGFloat = 14
    static let sectionPaddingH: CGFloat = 14
    static let sectionPaddingV: CGFloat = 14
    static let rowSpacing: CGFloat = 8
    static let fieldLabelWidth: CGFloat = 72
    static let sectionSpacing: CGFloat = 10
    static let hostIconSize: CGFloat = 32
    static let hostBadgeCornerRadius: CGFloat = 7
    static let contentInset: CGFloat = 10
    static let buttonSpacing: CGFloat = 10
    static let passwordToggleWidth: CGFloat = 32
    static let passwordFieldSpacing: CGFloat = 8
}

enum NetworkAuthSheetGlassStyle {
    static var sheetBackground: some View {
        RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous)
            .fill(.clear)
    }

    static var sheetBorder: some View {
        RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    static var sectionBorder: some View {
        RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    static var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.9))
    }

    static var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    static var passwordToggleBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.9))
    }

    static var passwordToggleBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    static var cancelButtonBackground: some View {
        Capsule()
            .fill(.quaternary.opacity(0.9))
    }

    static func sectionBackground(tint: Color = .clear) -> some View {
        RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous)
            .fill(tint)
    }
}

struct NetworkAuthCardInsets: ViewModifier {
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, NetworkAuthSheetLayout.contentInset)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

struct NetworkAuthSectionCard<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content

    init(tint: Color = .clear, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .background(NetworkAuthSheetGlassStyle.sectionBackground(tint: tint))
            .overlay(NetworkAuthSheetGlassStyle.sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.cornerRadius, style: .continuous))
    }
}

struct NetworkAuthGlassField<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(NetworkAuthSheetGlassStyle.fieldBackground)
            .overlay(NetworkAuthSheetGlassStyle.fieldBorder)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NetworkAuthHostCard: View {
    let host: NetworkHost

    var body: some View {
        HStack(spacing: NetworkAuthSheetLayout.rowSpacing + 2) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 22))
                .foregroundStyle(.blue)
                .frame(width: NetworkAuthSheetLayout.hostIconSize, height: NetworkAuthSheetLayout.hostIconSize)
                .background {
                    RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.hostBadgeCornerRadius, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: NetworkAuthSheetLayout.hostBadgeCornerRadius, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.8)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to \"\(host.name)\"")
                    .font(.headline.weight(.semibold))
                Text(host.hostName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !host.deviceLabel.isEmpty {
                Text(host.deviceLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(.quaternary.opacity(0.9))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.quaternary, lineWidth: 0.8)
                    }
            }
        }
        .padding(.horizontal, NetworkAuthSheetLayout.sectionPaddingH)
        .padding(.vertical, 12)
        .background {
            NetworkAuthSectionCard(tint: Color.blue.opacity(0.05)) {
                Color.clear
            }
        }
        .modifier(NetworkAuthCardInsets(topPadding: 10, bottomPadding: 0))
    }
}

struct NetworkAuthCredentialsSection: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var isPasswordVisible: Bool
    var focusedField: FocusState<NetworkAuthSheet.Field?>.Binding
    let passwordPrompt: String
    let onConfirm: () -> Void

    private var passwordToggleSymbol: String {
        isPasswordVisible ? "eye.slash" : "eye"
    }

    private var passwordToggleAccessibilityLabel: String {
        isPasswordVisible ? "Hide password" : "Show password"
    }

    var body: some View {
        VStack(spacing: NetworkAuthSheetLayout.sectionSpacing) {
            fieldRow(label: "Username", systemImage: "person") {
                NetworkAuthGlassField {
                    TextField("guest", text: $username)
                        .textFieldStyle(.plain)
                        .focused(focusedField, equals: .username)
                        .onSubmit { focusedField.wrappedValue = .password }
                }
            }

            fieldRow(label: "Password", systemImage: "lock") {
                HStack(spacing: NetworkAuthSheetLayout.passwordFieldSpacing) {
                    NetworkAuthGlassField {
                        if isPasswordVisible {
                            TextField(passwordPrompt, text: $password)
                                .textFieldStyle(.plain)
                                .focused(focusedField, equals: .password)
                                .onSubmit { onConfirm() }
                        } else {
                            SecureField(passwordPrompt, text: $password)
                                .textFieldStyle(.plain)
                                .focused(focusedField, equals: .password)
                                .onSubmit { onConfirm() }
                        }
                    }

                    Button {
                        isPasswordVisible.toggle()
                        focusedField.wrappedValue = .password
                    } label: {
                        Image(systemName: passwordToggleSymbol)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: NetworkAuthSheetLayout.passwordToggleWidth, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .background(NetworkAuthSheetGlassStyle.passwordToggleBackground)
                    .overlay(NetworkAuthSheetGlassStyle.passwordToggleBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .help(passwordToggleAccessibilityLabel)
                    .accessibilityLabel(passwordToggleAccessibilityLabel)
                }
            }
        }
        .padding(.horizontal, NetworkAuthSheetLayout.sectionPaddingH)
        .padding(.vertical, NetworkAuthSheetLayout.sectionPaddingV)
        .background {
            NetworkAuthSectionCard {
                Color.clear
            }
        }
        .modifier(NetworkAuthCardInsets(topPadding: 0, bottomPadding: 0))
    }

    @ViewBuilder
    private func fieldRow(label: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: NetworkAuthSheetLayout.rowSpacing) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: NetworkAuthSheetLayout.fieldLabelWidth, alignment: .trailing)

            content()
        }
    }
}

struct NetworkAuthButtonRow: View {
    let canConfirm: Bool
    let isSaving: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: NetworkAuthSheetLayout.buttonSpacing) {
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(NetworkAuthSheetGlassStyle.cancelButtonBackground)
                .overlay {
                    Capsule()
                        .strokeBorder(.quaternary, lineWidth: 0.8)
                }

            Spacer()

            Button {
                onConfirm()
            } label: {
                if isSaving {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Saving…")
                    }
                } else {
                    Label("Sign In", systemImage: "key.fill")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canConfirm)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.regular)
        }
        .padding(.horizontal, NetworkAuthSheetLayout.sectionPaddingH)
        .padding(.vertical, 10)
        .background {
            NetworkAuthSectionCard {
                Color.clear
            }
        }
        .modifier(NetworkAuthCardInsets(topPadding: 0, bottomPadding: 10))
    }
}

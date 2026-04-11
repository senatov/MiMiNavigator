// NetworkAuthSheet.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal sheet for entering SMB/FTP/SFTP credentials.
//              Saves to Keychain on confirm, calls onAuthenticated to retry share fetch.

import SwiftUI

// MARK: - Auth sheet: user + password entry for a network host
struct NetworkAuthSheet: View {

    let host: NetworkHost
    var onAuthenticated: () -> Void
    var onCancel: () -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSaving: Bool = false
    @State private var isPasswordVisible: Bool = false
    @FocusState private var focusedField: Field?

    private var canConfirm: Bool {
        !username.isEmpty && !isSaving
    }

    private var resolvedFocusField: Field {
        username.isEmpty ? .username : .password
    }

    private enum Field { case username, password }

    // MARK: - Layout
    private enum Layout {
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
        static let sectionVerticalPadding: CGFloat = 12
    }

    private var passwordPrompt: String {
        "Required"
    }

    private var passwordToggleSymbol: String {
        isPasswordVisible ? "eye.slash" : "eye"
    }

    private var passwordToggleAccessibilityLabel: String {
        isPasswordVisible ? "Hide password" : "Show password"
    }

    // MARK: - Glass Styling
    @ViewBuilder
    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var sheetBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private var hostBadgeBackground: some View {
        Capsule()
            .fill(.quaternary.opacity(0.9))
    }

    @ViewBuilder
    private var passwordToggleBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.9))
    }

    @ViewBuilder
    private var passwordToggleBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private func sectionBackground(tint: Color = .clear) -> some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(tint)
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.9))
    }

    @ViewBuilder
    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private var cancelButtonBackground: some View {
        Capsule()
            .fill(.quaternary.opacity(0.9))
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        tint: Color = .clear,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(sectionBackground(tint: tint))
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func glassField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Host card (matches HostNodeRow style)
    private var hostCard: some View {
        HStack(spacing: Layout.rowSpacing + 2) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 22))
                .foregroundStyle(.blue)
                .frame(width: Layout.hostIconSize, height: Layout.hostIconSize)
                .background {
                    RoundedRectangle(cornerRadius: Layout.hostBadgeCornerRadius, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.hostBadgeCornerRadius, style: .continuous)
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
        .padding(.horizontal, Layout.sectionPaddingH)
        .padding(.vertical, 12)
        .background {
            sectionCard(tint: Color.blue.opacity(0.05)) {
                Color.clear
            }
        }
        .modifier(HostCardContainer(topPadding: 10, bottomPadding: 0))
    }

    private struct HostCardContainer: ViewModifier {
        let topPadding: CGFloat
        let bottomPadding: CGFloat

        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Layout.contentInset)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
    }

    // MARK: - Input fields
    private var fieldsSection: some View {
        VStack(spacing: Layout.sectionSpacing) {
            usernameRow
            passwordRow
        }
        .padding(.horizontal, Layout.sectionPaddingH)
        .padding(.vertical, Layout.sectionPaddingV)
        .background {
            sectionCard {
                Color.clear
            }
        }
        .modifier(HostCardContainer(topPadding: 0, bottomPadding: 0))
    }

    private var usernameRow: some View {
        fieldRow(label: "Username", systemImage: "person") {
            glassField {
                TextField("guest", text: $username)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
            }
        }
    }

    private var passwordRow: some View {
        fieldRow(label: "Password", systemImage: "lock") {
            HStack(spacing: Layout.passwordFieldSpacing) {
                passwordInputField
                passwordVisibilityButton
            }
        }
    }

    @ViewBuilder
    private var passwordInputField: some View {
        glassField {
            if isPasswordVisible {
                TextField(passwordPrompt, text: $password)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .password)
                    .onSubmit { confirm() }
            } else {
                SecureField(passwordPrompt, text: $password)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .password)
                    .onSubmit { confirm() }
            }
        }
    }

    private var passwordVisibilityButton: some View {
        Button {
            isPasswordVisible.toggle()
            focusedField = .password
        } label: {
            Image(systemName: passwordToggleSymbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: Layout.passwordToggleWidth, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(passwordToggleBackground)
        .overlay(passwordToggleBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(passwordToggleAccessibilityLabel)
        .accessibilityLabel(passwordToggleAccessibilityLabel)
    }

    // MARK: - Single labeled field row
    @ViewBuilder
    private func fieldRow(label: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: Layout.fieldLabelWidth, alignment: .trailing)
            content()
        }
    }

    // MARK: - Buttons
    private var buttonRow: some View {
        HStack(spacing: Layout.buttonSpacing) {
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(cancelButtonBackground)
                .overlay {
                    Capsule()
                        .strokeBorder(.quaternary, lineWidth: 0.8)
                }
            Spacer()
            Button {
                confirm()
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
        .padding(.horizontal, Layout.sectionPaddingH)
        .padding(.vertical, 10)
        .background {
            sectionCard {
                Color.clear
            }
        }
        .modifier(HostCardContainer(topPadding: 0, bottomPadding: 10))
    }

    // MARK: - Pre-fill from Keychain; purge stale "No user account" ghost entries
    private func isStaleSavedCredentials(_ creds: NetworkCredentials) -> Bool {
        creds.user.isEmpty || creds.user.lowercased().contains("no user")
    }

    private func applySavedCredentials(_ creds: NetworkCredentials) {
        username = creds.user
        password = creds.password
    }

    private func prefill() {
        if let saved = NetworkAuthService.load(for: host.hostName) {
            if isStaleSavedCredentials(saved) {
                NetworkAuthService.delete(for: host.hostName)
                log.info("[Auth] purged stale Keychain entry for \(host.hostName)")
            } else {
                applySavedCredentials(saved)
            }
        }

        isPasswordVisible = false
        focusedField = resolvedFocusField
    }

    // MARK: - Save + callback
    private func scheduleAuthenticationCompletion() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            completeAuthentication()
        }
    }

    private func completeAuthentication() {
        isSaving = false
        onAuthenticated()
    }

    private func confirm() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }

        username = trimmedUsername
        isSaving = true
        let creds = NetworkCredentials(user: trimmedUsername, password: password)
        NetworkAuthService.save(creds, for: host.hostName)
        log.info("[Auth] credentials confirmed for \(host.hostName)")
        scheduleAuthenticationCompletion()
    }

    // MARK: -
    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            hostCard
            fieldsSection
            buttonRow
        }
        .frame(width: Layout.dialogWidth)
        .padding(.vertical, 2)
        .background(sheetBackground)
        .glassEffect(.regular)
        .overlay(sheetBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .onAppear { prefill() }
    }
}

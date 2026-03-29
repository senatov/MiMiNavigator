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
        static let dialogWidth: CGFloat = 360
        static let cornerRadius: CGFloat = 12
        static let sectionPaddingH: CGFloat = 14
        static let sectionPaddingV: CGFloat = 14
        static let rowSpacing: CGFloat = 8
        static let fieldLabelWidth: CGFloat = 64
        static let sectionSpacing: CGFloat = 10
        static let hostIconSize: CGFloat = 32
        static let hostBadgeCornerRadius: CGFloat = 7
    }
    private enum Glass {
        static let cardCornerRadius: CGFloat = 14
        static let controlCornerRadius: CGFloat = 10
        static let borderOpacity: Double = 0.12
        static let hoverTintOpacity: Double = 0.10
        static let sectionTintOpacity: Double = 0.06
    }

    // MARK: - Glass Styling
    @ViewBuilder
    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private var sheetBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private var hostBadgeBackground: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.hoverTintOpacity)))
    }

    @ViewBuilder
    private func sectionBackground(tint: Color = Color.white.opacity(Glass.sectionTintOpacity)) -> some View {
        RoundedRectangle(cornerRadius: Glass.cardCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(tint))
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Glass.cardCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Glass.controlCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: Glass.controlCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private var cancelButtonBackground: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        tint: Color = Color.white.opacity(Glass.sectionTintOpacity),
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(sectionBackground(tint: tint))
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Glass.cardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func glassField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .clipShape(RoundedRectangle(cornerRadius: Glass.controlCornerRadius, style: .continuous))
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
                        .fill(.clear)
                        .glassEffect(.regular.tint(Color.blue.opacity(0.12)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.hostBadgeCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to \"\(host.name)\"")
                    .font(.subheadline.weight(.light))
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
                    .background(hostBadgeBackground)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
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
                .padding(.horizontal, 10)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
    }

    // MARK: - Input fields
    private var fieldsSection: some View {
        VStack(spacing: Layout.sectionSpacing) {
            fieldRow(label: "Username", systemImage: "person") {
                glassField {
                    TextField("guest", text: $username)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .password }
                }
            }
            fieldRow(label: "Password", systemImage: "lock") {
                glassField {
                    SecureField("Required", text: $password)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .password)
                        .onSubmit { confirm() }
                }
            }
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

    // MARK: - Single labeled field row
    @ViewBuilder
    private func fieldRow(label: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: Layout.fieldLabelWidth, alignment: .trailing)
            content()
        }
    }

    // MARK: - Buttons
    private var buttonRow: some View {
        HStack(spacing: 10) {
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(cancelButtonBackground)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
                }
            Spacer()
            Button {
                confirm()
            } label: {
                if isSaving {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Connecting…")
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
        guard !username.isEmpty else { return }
        isSaving = true
        let creds = NetworkCredentials(user: username, password: password)
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
        .overlay(sheetBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .onAppear { prefill() }
    }
}

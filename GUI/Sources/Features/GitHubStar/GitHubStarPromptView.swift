// GitHubStarPromptView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Non-blocking GitHub star prompt and toolbar badge.

import AppKit
import SwiftUI

// MARK: - GitHubStarPromptView

struct GitHubStarPromptView: View {
    @Binding var isPresented: Bool
    let store: GitHubStarAcknowledgementStore

    @State private var saveFailed = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            header
            explanation
            buttons
        }
        .padding(28)
        .frame(width: 470)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.yellow)
            Text("Enjoying MiMiNavigator?")
                .font(.system(size: 18, weight: .semibold))
            Text("A GitHub star helps more macOS users discover the project and supports its path toward the official Homebrew catalog.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 410)
        }
    }

    // MARK: - Explanation

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 9) {
            infoRow(icon: "hand.thumbsup", text: "Starring is optional and MiMiNavigator remains completely free.")
            infoRow(icon: "safari", text: "Open the project on GitHub, sign in there, and click Star.")
            infoRow(icon: "lock.shield", text: "MiMiNavigator does not request your GitHub login or access token.")
            if saveFailed {
                Label("The local acknowledgement could not be saved. Please try again.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.85), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            DownToolbarButtonView(title: "Not Now", systemImage: "clock") {
                isPresented = false
            }
            .keyboardShortcut(.escape)
            Spacer()
            DownToolbarButtonView(title: "Open GitHub", systemImage: "safari") {
                openRepository()
            }
            DownToolbarButtonView(title: "I Starred It", systemImage: "star.fill") {
                acknowledgeStar()
            }
            .keyboardShortcut(.return)
        }
    }

    // MARK: - Info Row

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Open Repository

    private func openRepository() {
        NSWorkspace.shared.open(GitHubStarAcknowledgementStore.repositoryURL)
    }

    // MARK: - Acknowledge Star

    private func acknowledgeStar() {
        saveFailed = !store.markAcknowledged()
        if !saveFailed {
            isPresented = false
        }
    }
}

// MARK: - GitHubStarBadge

struct GitHubStarBadge: View {
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 0) {
                    Text("STAR ON GITHUB")
                        .font(.system(size: 9.5, weight: .semibold, design: .default))
                        .tracking(0.45)
                    Text("Help the project grow")
                        .font(.system(size: 9.5, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.yellow.opacity(0.6), lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Star MiMiNavigator on GitHub")
        .accessibilityLabel("Star MiMiNavigator on GitHub")
    }
}

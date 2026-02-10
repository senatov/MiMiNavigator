// FindFilesPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Non-modal Find Files panel (Total Commander style) — main container view

import SwiftUI

// MARK: - Find Files Panel
/// Non-modal search panel that slides in from the bottom or side,
/// allowing the user to continue working with file panels while searching.
struct FindFilesPanel: View {
    @Environment(AppState.self) var appState
    @Bindable var viewModel: FindFilesViewModel
    let onDismiss: () -> Void

    @State private var selectedTab: FindFilesTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Title Bar
            titleBar

            Divider()

            // MARK: - Tab Selection
            tabBar

            // MARK: - Tab Content
            tabContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // MARK: - Results Section
            FindFilesResultsView(viewModel: viewModel, appState: appState)

            Divider()

            // MARK: - Status Bar & Action Buttons
            bottomBar
        }
        .frame(minWidth: 600, idealWidth: 720, minHeight: 400, idealHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onAppear {
            viewModel.configure(searchPath: currentPanelPath)
        }
        // Archive password dialog
        .sheet(isPresented: $viewModel.showPasswordDialog) {
            ArchivePasswordDialog(
                archiveName: viewModel.passwordArchiveName,
                password: $viewModel.archivePassword,
                onSubmit: { viewModel.submitArchivePassword() },
                onSkip: { viewModel.skipArchive() }
            )
        }
    }

    // MARK: - Title Bar
    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Find Files")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            // Live stats during search
            if viewModel.searchState == .searching {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)

                    Text("\(viewModel.stats.filesScanned) files scanned")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (⎋)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FindFilesTab.allCases) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func tabButton(_ tab: FindFilesTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Text(tab.title)
                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedTab == tab
                        ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12))
                        : nil
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            FindFilesGeneralTab(viewModel: viewModel)
        case .advanced:
            FindFilesAdvancedTab(viewModel: viewModel)
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 8) {
            // Statistics
            statusText
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            // Error message
            if let error = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action Buttons
            if viewModel.searchState == .searching {
                HIGSecondaryButton(title: "Cancel") {
                    viewModel.cancelSearch()
                }
                .keyboardShortcut(.cancelAction)
            } else {
                if !viewModel.results.isEmpty {
                    HIGSecondaryButton(title: "New Search") {
                        viewModel.newSearch()
                    }
                }

                HIGPrimaryButton(title: "Search") {
                    viewModel.startSearch()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.searchState == .searching)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Status Text
    private var statusText: some View {
        Group {
            switch viewModel.searchState {
            case .idle:
                Text("Ready")
            case .searching:
                Text("Searching… \(viewModel.results.count) found · \(viewModel.stats.formattedElapsed)")
            case .completed:
                Text("Done: \(viewModel.results.count) found in \(viewModel.stats.formattedElapsed) · \(viewModel.stats.directoriesScanned) dirs · \(viewModel.stats.filesScanned) files")
            case .cancelled:
                Text("Cancelled: \(viewModel.results.count) found")
            case .paused:
                Text("Paused")
            }
        }
    }

    // MARK: - Helpers
    private var currentPanelPath: String {
        appState.focusedPanel == .left ? appState.leftPath : appState.rightPath
    }
}

// MARK: - Tab Enum
enum FindFilesTab: String, CaseIterable, Identifiable {
    case general = "General"
    case advanced = "Advanced"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .advanced: return "Advanced"
        }
    }
}

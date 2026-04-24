// FindFilesWindowContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main content view for the standalone Find Files window

import SwiftUI

// MARK: - Find Files Window Content
struct FindFilesWindowContent: View {
    @Bindable var viewModel: FindFilesViewModel
    var appState: AppState?
    @State private var selectedTab: FindFilesTab = .general

    private var dialogBgColor: Color {
        let store = ColorThemeStore.shared
        if !store.hexDialogBackground.isEmpty, let c = Color(hex: store.hexDialogBackground) {
            return c
        }
        return store.activeTheme.dialogBackground
    }

    var body: some View {
        ZStack {
            dialogBgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("General").tag(FindFilesTab.general)
                    Text("Advanced").tag(FindFilesTab.advanced)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

                // MARK: - Input Area with visible border + spinner overlay
                ZStack {
                    inputAreaWithBorder
                    if viewModel.searchState == .searching {
                        searchSpinnerOverlay
                    }
                }
                .padding(.horizontal, 10)

                // MARK: - Action Bar (Search / Close) — tight to input
                actionBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(actionBarBackground)
                    .overlay(actionBarBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 6)

                // MARK: - Sharp separator line
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)

                // MARK: - Results Table (fills all remaining space)
                FindFilesResultsView(viewModel: viewModel, appState: appState)
                    .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)

                // MARK: - Status Bar
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
            }
            .font(.system(size: 12))
            // Archive password dialog
            .sheet(isPresented: Binding(
                get: { viewModel.showPasswordDialog },
                set: { viewModel.showPasswordDialog = $0 }
            )) {
                ArchivePasswordDialog(
                    archiveName: viewModel.passwordArchiveName,
                    password: Binding(
                        get: { viewModel.archivePassword },
                        set: { viewModel.archivePassword = $0 }
                    ),
                    onSubmit: { viewModel.submitArchivePassword() },
                    onSkip: { viewModel.skipArchive() }
                )
            }
            // Error alert
            .alert("Search Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Input Area with Border

    private var inputAreaWithBorder: some View {
        Group {
            switch selectedTab {
            case .general:
                FindFilesGeneralTab(viewModel: viewModel)
            case .advanced:
                FindFilesAdvancedTab(viewModel: viewModel)
            }
        }
        .fixedSize(horizontal: false, vertical: selectedTab == .general)
        .frame(height: selectedTab == .advanced ? 360 : nil)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DialogColors.light.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.55), lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            // Result count badge (left side)
            if !viewModel.results.isEmpty {
                Text("\(viewModel.results.count) found")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }

            Spacer()

            // Show in Panel — inject results into focused panel
            if let appState, !viewModel.results.isEmpty {
                Button {
                    // showInPanel extracts archives async; close dialog after injection completes
                    viewModel.cancelSearch()
                    viewModel.showInPanel(appState: appState)
                    // Close on next run loop tick — gives showInPanel's Task time to start
                    DispatchQueue.main.async {
                        FindFilesCoordinator.shared.close()
                    }
                } label: {
                    Label("Show in Panel", systemImage: "sidebar.squares.left")
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.regular)
                .help("Display search results in the focused panel")
            }

            // macOS canonical layout: secondary buttons left, primary button rightmost
            // New Search (secondary)
            Button("New Search") {
                viewModel.newSearch()
            }
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.regular)
            .disabled(viewModel.searchState == .idle && viewModel.results.isEmpty)

            // Primary: Search / Stop (rightmost)
            if viewModel.searchState == .searching {
                Button("Stop", role: .destructive) {
                    viewModel.cancelSearch()
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.regular)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Button {
                    viewModel.startSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    private var actionBarBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DialogColors.light.opacity(0.98))
    }

    private var actionBarBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(DialogColors.border.opacity(0.42), lineWidth: 0.5)
    }

    // MARK: - Status Bar
    /// HIG-compliant status bar: system colors, readable font, live path display during search
    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Top row: state indicator + statistics
            HStack(spacing: 10) {
                // State indicator with system-appropriate styling
                HStack(spacing: 4) {
                    switch viewModel.searchState {
                    case .idle:
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                        Text("Ready")
                            .foregroundStyle(.secondary)
                    case .searching:
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching\u{2026}")
                            .foregroundStyle(.primary)
                    case .paused:
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("Paused")
                            .foregroundStyle(.primary)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Completed")
                            .foregroundStyle(.primary)
                    case .cancelled:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Text("Cancelled")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)

                Spacer()

                // Statistics (right side)
                if viewModel.stats.filesScanned > 0 {
                    HStack(spacing: 6) {
                        Text("\(viewModel.stats.directoriesScanned) dirs")
                        Text("\u{00B7}")
                        Text("\(viewModel.stats.filesScanned) files")
                        if viewModel.stats.archivesScanned > 0 {
                            Text("\u{00B7}")
                            Text("\(viewModel.stats.archivesScanned) archives")
                        }
                        Text("\u{00B7}")
                        Text(viewModel.stats.formattedElapsed)
                    }
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            // Bottom row: current path (visible during search)
            if viewModel.searchState == .searching, !viewModel.stats.currentPath.isEmpty {
                Text(viewModel.stats.currentPath)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.stats.currentPath)
            }
        }
    }

    // MARK: - Search Spinner Overlay
    /// Large non-blocking spinner centered over the input area during search.
    /// Uses allowsHitTesting(false) so all inputs remain fully interactive.
    private var searchSpinnerOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.5)
                Text("\(viewModel.results.count) found")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}

// MARK: - Tab Enum
enum FindFilesTab: String, Identifiable {
    case general
    case advanced
    var id: String { rawValue }
}

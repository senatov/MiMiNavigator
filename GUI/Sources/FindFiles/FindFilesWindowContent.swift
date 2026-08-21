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
    @State private var criteriaHeight: CGFloat = 390
    @State private var didRestoreLayout = false

    private var dialogBgColor: Color {
        let store = ColorThemeStore.shared
        if !store.hexDialogBackground.isEmpty, let c = Color(hex: store.hexDialogBackground) {
            return c
        }
        return store.activeTheme.dialogBackground
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                dialogBgColor.ignoresSafeArea()
                VStack(spacing: 0) {
                    criteriaPane
                        .frame(height: clampedCriteriaHeight(totalHeight: geometry.size.height))
                    FindFilesSplitDivider(
                        criteriaHeight: $criteriaHeight,
                        totalHeight: geometry.size.height
                    )
                    FindFilesResultsView(viewModel: viewModel, appState: appState)
                        .frame(maxHeight: .infinity)
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                    statusBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                }
                .font(.system(size: 12))
                .keyboardFocusSection()
            }
        }
        .onAppear {
            guard !didRestoreLayout else { return }
            didRestoreLayout = true
            let storedHeight = MiMiDefaults.shared.double(forKey: "findFiles.criteriaPaneHeight")
            if storedHeight > 0 { criteriaHeight = CGFloat(storedHeight) }
            if let rawTab = MiMiDefaults.shared.string(forKey: "findFiles.selectedTab"),
               let restoredTab = FindFilesTab(rawValue: rawTab)
            {
                selectedTab = restoredTab
            }
            viewModel.activeModule = selectedTab
        }
        .onChange(of: selectedTab) {
            viewModel.activeModule = selectedTab
            MiMiDefaults.shared.set(selectedTab.rawValue, forKey: "findFiles.selectedTab")
        }
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
        .alert("Search Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            viewModel.savePreferences()
        }
    }

    // MARK: - Criteria Pane

    private var criteriaPane: some View {
        VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("GLOBAL FILE SEARCH")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.55)
                    Text(viewModel.searchDirectory.isEmpty ? "Choose a location" : viewModel.searchDirectory)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 9)

                // MARK: - Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Search").tag(FindFilesTab.general)
                    Text("Advanced").tag(FindFilesTab.advanced)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.top, 7)
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
        .frame(maxHeight: .infinity)
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
                Text(viewModel.stats.resultLimitReached
                    ? "\(viewModel.results.count)+ found · refine search"
                    : "\(viewModel.results.count) found")
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
                    viewModel.cancelSearch()
                    viewModel.showInPanel(appState: appState)
                } label: {
                    Label("Show in Panel", systemImage: "sidebar.squares.left")
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.regular)
                .help("Display search results in the focused panel")
            }

            Button {
                viewModel.clearResults()
            } label: {
                Label("Clear Results", systemImage: "xmark.bin")
            }
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.regular)
            .disabled(viewModel.results.isEmpty || viewModel.searchState == .searching)

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
            .strokeBorder(DialogColors.border.opacity(0.75), lineWidth: 1)
    }

    private func clampedCriteriaHeight(totalHeight: CGFloat) -> CGFloat {
        min(max(criteriaHeight, 250), max(250, totalHeight - 190))
    }

    // MARK: - Status Bar
    /// HIG-compliant status bar: system colors, readable font, live path display during search
    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
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
                .font(.system(size: 11))

                FindFilesCriteriaHeader(criteria: viewModel.activeCriteriaSummary)
                Spacer()
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
                        Text("\u{00B7}")
                        Text(viewModel.stats.backend == .spotlight ? "Spotlight" : "find")
                        if viewModel.stats.resultLimitReached {
                            Text("\u{00B7} result limit reached")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
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

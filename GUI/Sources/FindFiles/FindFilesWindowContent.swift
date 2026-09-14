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
    @State private var criteriaHeight: CGFloat = 10000
    @State private var didRestoreLayout = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        totalHeight: geometry.size.height,
                        persistenceKey: criteriaHeightKey(for: selectedTab),
                        minimumHeight: minimumCriteriaHeight
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
                .font(DesignTokens.Typography.body)
                .keyboardFocusSection()
            }
            .onChange(of: geometry.size.height) { oldHeight, newHeight in
                criteriaHeight = clampedCriteriaHeight(totalHeight: oldHeight) + newHeight - oldHeight
            }
        }
        .onAppear {
            guard !didRestoreLayout else { return }
            didRestoreLayout = true
            if let rawTab = MiMiDefaults.shared.string(forKey: "findFiles.selectedTab"),
               let restoredTab = FindFilesTab(rawValue: rawTab)
            {
                selectedTab = restoredTab
            }
            criteriaHeight = restoredCriteriaHeight(for: selectedTab)
            viewModel.activeModule = selectedTab
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard viewModel.activeModule != newTab else { return }
            MiMiDefaults.shared.set(Double(criteriaHeight), forKey: criteriaHeightKey(for: oldTab))
            criteriaHeight = restoredCriteriaHeight(for: newTab)
            viewModel.activeModule = newTab
            MiMiDefaults.shared.set(newTab.rawValue, forKey: "findFiles.selectedTab")
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
        .inAppNoticeHost(scope: .findFiles)
        .onChange(of: viewModel.errorMessage) { _, message in
            guard let message else { return }
            InAppNoticeCenter.shared.showBanner(title: "Search Error", message: message, scope: .findFiles)
            viewModel.errorMessage = nil
        }
        .onDisappear {
            MiMiDefaults.shared.set(Double(criteriaHeight), forKey: criteriaHeightKey(for: selectedTab))
            viewModel.savePreferences()
        }
    }

    // MARK: - Criteria Pane

    private var criteriaPane: some View {
        VStack(spacing: 0) {
            FindFilesSearchLocation(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.22), radius: 3, y: 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("File Search")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.searchDirectory.isEmpty ? "Choose a location" : viewModel.searchDirectory)
                        .font(DesignTokens.Typography.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 16)
                Picker("", selection: $selectedTab) {
                    Text("Search").tag(FindFilesTab.general)
                    Text("Advanced").tag(FindFilesTab.advanced)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle().fill(DialogColors.border.opacity(0.55)).frame(height: 0.5)
            }
            ZStack {
                inputAreaWithBorder
                if viewModel.searchState == .searching {
                    searchSpinnerOverlay
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            FindFilesActiveFiltersBar(viewModel: viewModel)
                .padding(.horizontal, 12)
                .padding(.top, 6)
            actionBar
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(actionBarBackground)
                .overlay(alignment: .top) {
                    Rectangle().fill(DialogColors.border.opacity(0.45)).frame(height: 0.5)
                }
                .padding(.top, 8)
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
                .fill(DialogColors.base.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.72), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.045), radius: 4, y: 1)
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
            Button {
                FindFilesCoordinator.shared.showResultsWindow()
            } label: {
                Label("Results Window", systemImage: "arrow.up.forward.square")
            }
            .buttonStyle(ThemedButtonStyle())
            .help("Open live search results in a separate resizable window")

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
        DialogColors.stripe.opacity(0.35)
    }

    private func clampedCriteriaHeight(totalHeight: CGFloat) -> CGFloat {
        min(max(criteriaHeight, minimumCriteriaHeight), max(minimumCriteriaHeight, totalHeight - 160))
    }

    private func criteriaHeightKey(for tab: FindFilesTab) -> String {
        "findFiles.criteriaPaneHeight.compact.\(tab.rawValue)"
    }

    private func restoredCriteriaHeight(for tab: FindFilesTab) -> CGFloat {
        let storedHeight = MiMiDefaults.shared.double(forKey: criteriaHeightKey(for: tab))
        guard storedHeight > 0 else { return 10000 }
        return CGFloat(storedHeight)
    }

    private var minimumCriteriaHeight: CGFloat {
        selectedTab == .general ? 260 : 360
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
                .font(DesignTokens.Typography.caption)

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
                    .font(DesignTokens.Typography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
            if viewModel.searchState == .searching, !viewModel.stats.currentPath.isEmpty {
                Text(viewModel.stats.currentPath)
                    .font(DesignTokens.Typography.path)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: viewModel.stats.currentPath)
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
        .transition(reduceMotion ? .identity : .opacity.animation(.easeInOut(duration: 0.2)))
    }
}

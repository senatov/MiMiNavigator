// FindFilesWindowContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Refactored: 11.02.2026 — native macOS 26 HIG layout
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main content view for the standalone Find Files window

import SwiftUI

// MARK: - Find Files Window Content
/// Uses native macOS Form layout, standard button styles, and system materials.
struct FindFilesWindowContent: View {
    @Bindable var viewModel: FindFilesViewModel
    @State private var selectedTab: FindFilesTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Action Bar
            actionBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // MARK: - Tab Picker
            Picker("", selection: $selectedTab) {
                Text("General").tag(FindFilesTab.general)
                Text("Advanced").tag(FindFilesTab.advanced)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // MARK: - Tab Content (native Form inside each tab)
            Group {
                switch selectedTab {
                case .general:
                    FindFilesGeneralTab(viewModel: viewModel)
                case .advanced:
                    FindFilesAdvancedTab(viewModel: viewModel)
                }
            }

            Divider()

            // MARK: - Results Table
            FindFilesResultsView(viewModel: viewModel)
                .frame(minHeight: 140)

            Divider()

            // MARK: - Status Bar
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Primary: Search / Stop
            if viewModel.searchState == .searching {
                Button("Stop", role: .destructive) {
                    viewModel.cancelSearch()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            } else {
                Button {
                    viewModel.startSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }

            // Secondary: New Search
            Button("New Search") {
                viewModel.newSearch()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.searchState == .idle && viewModel.results.isEmpty)

            Spacer()

            // Result count
            if !viewModel.results.isEmpty {
                Text("\(viewModel.results.count) found")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            Group {
                switch viewModel.searchState {
                case .idle:
                    Label("Ready", systemImage: "circle")
                        .foregroundStyle(Color(#colorLiteral(red: 0.4, green: 0.45, blue: 0.5, alpha: 1)))
                case .searching:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching\u{2026}")
                            .foregroundStyle(.primary)
                    }
                case .paused:
                    Label("Paused", systemImage: "pause.circle")
                        .foregroundStyle(.orange)
                case .completed:
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color(#colorLiteral(red: 0.15, green: 0.68, blue: 0.38, alpha: 1)))
                case .cancelled:
                    Label("Cancelled", systemImage: "xmark.circle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12, weight: .medium))

            Spacer()

            // Statistics
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
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(#colorLiteral(red: 0.4, green: 0.42, blue: 0.48, alpha: 1)))
            }
        }
    }
}

// MARK: - Tab Enum
enum FindFilesTab: String, Identifiable {
    case general
    case advanced
    var id: String { rawValue }
}

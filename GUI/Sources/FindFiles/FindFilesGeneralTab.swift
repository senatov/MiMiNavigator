// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 18.02.2026 — clean HIG 26 layout, no inner borders, matches screenshot
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ── Search Criteria ──────────────────────────────────────
            sectionHeader(title: "Search Criteria", icon: "magnifyingglass", color: .blue)

            VStack(spacing: 10) {
                fieldRow(label: "Search for:", icon: "doc.text", iconColor: .orange) {
                    HStack(spacing: 6) {
                        SearchHistoryComboBox(
                            text: $viewModel.fileNamePattern,
                            historyKey: .fileNamePattern,
                            placeholder: "File name pattern",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: showPatternHelp) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Pattern syntax help")
                    }
                }

                fieldRow(label: "Search in:", icon: "folder.fill", iconColor: .blue) {
                    HStack(spacing: 6) {
                        SearchHistoryComboBox(
                            text: $viewModel.searchDirectory,
                            historyKey: .searchDirectory,
                            placeholder: "Directory path",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: browseDirectory) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Browse…")
                    }
                }

                fieldRow(label: "Find text:", icon: "text.magnifyingglass", iconColor: .purple) {
                    SearchHistoryComboBox(
                        text: $viewModel.searchText,
                        historyKey: .searchText,
                        placeholder: "Text to find inside files",
                        onSubmit: { viewModel.startSearch() }
                    )
                    .frame(height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            sectionDivider()

            // ── Options ──────────────────────────────────────────────
            sectionHeader(title: "Options", icon: "gearshape", color: .secondary)

            VStack(spacing: 0) {
                optionToggle(
                    title: "Case sensitive",
                    icon: "textformat",
                    iconColor: .indigo,
                    isOn: $viewModel.caseSensitive
                )
                optionDivider()
                optionToggle(
                    title: "Regular expressions",
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .teal,
                    isOn: $viewModel.useRegex
                )
                optionDivider()
                optionToggle(
                    title: "Include subdirectories",
                    icon: "folder.fill.badge.gearshape",
                    iconColor: .blue,
                    isOn: $viewModel.searchInSubdirectories
                )
                optionDivider()
                optionToggle(
                    title: "Search in archives",
                    icon: "archivebox.fill",
                    iconColor: .brown,
                    isOn: $viewModel.searchInArchives
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Section Divider (between sections)
    private func sectionDivider() -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
    }

    // MARK: - Option Row Divider (inside options block)
    private func optionDivider() -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 44)
    }

    // MARK: - Field Row (label + content)
    private func fieldRow<Content: View>(
        label: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
                    .frame(width: 18, alignment: .center)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 118, alignment: .leading)

            content()
        }
    }

    // MARK: - Option Toggle Row
    private func optionToggle(
        title: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 22, alignment: .center)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Browse
    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: viewModel.searchDirectory)
        panel.prompt = "Select"
        panel.message = "Choose directory, file, or archive to search in"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.searchDirectory = url.path
        }
    }

    // MARK: - Pattern Help
    private func showPatternHelp() {
        let alert = NSAlert()
        alert.messageText = "File Name Pattern Syntax"
        alert.informativeText = """
        Wildcards:
          *      — matches any number of characters
          ?      — matches exactly one character

        Examples:
          *.txt          — all text files
          *.swift;*.java — Swift and Java files
          report*        — files starting with "report"
          photo?.jpg     — photo1.jpg, photoA.jpg, etc.
          *.*            — all files with extension

        Separate multiple patterns with semicolons (;)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 14.02.2026 — ComboBox with history, blue borders, Word-Einstellungen style
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name, search text, directory, options

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Fields Section
            sectionHeader(title: "Search Criteria", icon: "magnifyingglass", color: .blue)

            VStack(spacing: 12) {
                // Search For (file name pattern)
                fieldRow(label: "Search for:", icon: "doc.text", iconColor: .orange) {
                    HStack(spacing: 8) {
                        SearchHistoryComboBox(
                            text: $viewModel.fileNamePattern,
                            historyKey: .fileNamePattern,
                            placeholder: "File name pattern",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: { showPatternHelp() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Pattern syntax help")
                    }
                }

                // Search In (directory)
                fieldRow(label: "Search in:", icon: "folder.fill", iconColor: .blue) {
                    HStack(spacing: 8) {
                        SearchHistoryComboBox(
                            text: $viewModel.searchDirectory,
                            historyKey: .searchDirectory,
                            placeholder: "Directory path",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: { browseDirectory() }) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Browse…")
                    }
                }

                // Find Text (content search)
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
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                    .padding(.horizontal, 8)
            )

            sectionDivider()

            // MARK: - Options Section
            sectionHeader(title: "Options", icon: "gearshape.fill", color: .gray)

            VStack(spacing: 8) {
                optionToggle(
                    title: "Case sensitive",
                    icon: "textformat",
                    iconColor: .indigo,
                    isOn: $viewModel.caseSensitive
                )
                optionToggle(
                    title: "Regular expressions",
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .teal,
                    isOn: $viewModel.useRegex
                )
                optionToggle(
                    title: "Include subdirectories",
                    icon: "folder.fill.badge.gearshape",
                    iconColor: .blue,
                    isOn: $viewModel.searchInSubdirectories
                )
                optionToggle(
                    title: "Search in archives",
                    icon: "archivebox.fill",
                    iconColor: .brown,
                    isOn: $viewModel.searchInArchives
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                    .padding(.horizontal, 8)
            )

            Spacer().frame(height: 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Section Header (Word-Einstellungen style)

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Section Divider

    private func sectionDivider() -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    // MARK: - Field Row

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
            .frame(width: 120, alignment: .leading)

            content()
        }
    }

    // MARK: - Option Toggle

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
        .padding(.vertical, 2)
    }

    // MARK: - Browse Directory
    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: viewModel.searchDirectory)
        panel.prompt = "Select"
        panel.message = "Choose search directory"
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

        Separate multiple patterns with semicolon (;)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

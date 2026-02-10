// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name pattern, search text, directory

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Search For (file name pattern)
            LabeledField(label: "Search for:") {
                HStack(spacing: 8) {
                    TextField("*.txt; *.swift; report*", text: $viewModel.fileNamePattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .help("Use wildcards: * (any chars) and ? (single char). Separate patterns with ;")

                    Button(action: { showPatternHelp() }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Pattern syntax help")
                }
            }

            // MARK: - Search In (directory)
            LabeledField(label: "Search in:") {
                HStack(spacing: 8) {
                    TextField("/Users/...", text: $viewModel.searchDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    Button(action: { browseDirectory() }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .help("Browse for directory")
                }
            }

            // MARK: - Find Text (content search)
            LabeledField(label: "Find text:") {
                TextField("Search inside file contents…", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .help("Leave empty for filename-only search")
            }

            // MARK: - Options Row
            HStack(spacing: 16) {
                Toggle("Case sensitive", isOn: $viewModel.caseSensitive)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Toggle("Regex", isOn: $viewModel.useRegex)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Toggle("Subdirectories", isOn: $viewModel.searchInSubdirectories)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Toggle("Search in archives", isOn: $viewModel.searchInArchives)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
            .padding(.top, 4)
        }
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

// MARK: - Labeled Field Helper
/// Consistent layout for label + field pairs
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            content
        }
    }
}

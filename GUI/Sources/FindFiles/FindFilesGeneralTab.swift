// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 12.02.2026 — fixed Backspace in TextFields, added Enter-to-search
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name, search text, directory, options

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    // MARK: - Design Constants
    private enum Design {
        static let fieldMinWidth: CGFloat = 320
        static let labelColor = Color.primary
    }

    var body: some View {
        Form {
            // MARK: - Search For (file name pattern)
            searchForSection

            // MARK: - Search In (directory)
            searchInSection

            // MARK: - Find Text (content search)
            findTextSection

            // MARK: - Options
            Section {
                Toggle(isOn: $viewModel.caseSensitive) {
                    Text("Case sensitive").font(.system(size: 13))
                }
                Toggle(isOn: $viewModel.useRegex) {
                    Text("Regular expressions").font(.system(size: 13))
                }
                Toggle(isOn: $viewModel.searchInSubdirectories) {
                    Text("Include subdirectories").font(.system(size: 13))
                }
                Toggle(isOn: $viewModel.searchInArchives) {
                    Text("Search in archives").font(.system(size: 13))
                }
            } header: {
                Text("Options")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Search For Section
    private var searchForSection: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("*.txt; *.swift; report*", text: $viewModel.fileNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(minWidth: Design.fieldMinWidth)
                    .help("Wildcards: * (any chars), ? (single char). Separate with ;")
                    .onSubmit { viewModel.startSearch() }

                Button(action: { showPatternHelp() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(#colorLiteral(red: 0.35, green: 0.35, blue: 0.45, alpha: 1)))
                }
                .buttonStyle(.plain)
                .help("Pattern syntax help")
            }
        } label: {
            Text("Search for:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.labelColor)
        }
    }

    // MARK: - Search In Section
    private var searchInSection: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("Select directory…", text: $viewModel.searchDirectory)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(minWidth: Design.fieldMinWidth)
                    .help("Directory to search in")
                    .onSubmit { viewModel.startSearch() }

                Button(action: { browseDirectory() }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Browse…")
            }
        } label: {
            Text("Search in:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.labelColor)
        }
    }

    // MARK: - Find Text Section
    private var findTextSection: some View {
        LabeledContent {
            TextField("Search inside file contents…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(minWidth: Design.fieldMinWidth)
                .help("Leave empty for filename-only search")
                .onSubmit { viewModel.startSearch() }
        } label: {
            Text("Find text:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.labelColor)
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

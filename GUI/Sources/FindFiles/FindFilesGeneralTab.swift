// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 12.02.2026 — fixed placeholder display, Backspace, Enter-to-search, HIG 26 fonts
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name, search text, directory, options

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

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
                    Label("Case sensitive", systemImage: "textformat")
                }
                Toggle(isOn: $viewModel.useRegex) {
                    Label("Regular expressions", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Toggle(isOn: $viewModel.searchInSubdirectories) {
                    Label("Include subdirectories", systemImage: "folder.badge.gearshape")
                }
                Toggle(isOn: $viewModel.searchInArchives) {
                    Label("Search in archives", systemImage: "archivebox")
                }
            } header: {
                Label("Options", systemImage: "gearshape")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Search For Section
    private var searchForSection: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("File name pattern", text: $viewModel.fileNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.startSearch() }
                    .help("Wildcards: * (any chars), ? (single char). Separate patterns with ;")

                Button(action: { showPatternHelp() }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Pattern syntax help")
            }
        } label: {
            Text("Search for:")
        }
    }

    // MARK: - Search In Section
    private var searchInSection: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField("Directory path", text: $viewModel.searchDirectory)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.startSearch() }
                    .help("Directory to search in")

                Button(action: { browseDirectory() }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Browse…")
            }
        } label: {
            Text("Search in:")
        }
    }

    // MARK: - Find Text Section
    private var findTextSection: some View {
        LabeledContent {
            TextField("Text to find inside files", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.startSearch() }
                .help("Leave empty for filename-only search")
        } label: {
            Text("Find text:")
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

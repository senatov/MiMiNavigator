// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 11.02.2026 — native macOS 26 Form style
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name, search text, directory, options

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        Form {
            // MARK: - Search For (file name pattern)
            LabeledContent("Search for:") {
                HStack(spacing: 6) {
                    TextField("*.txt; *.swift; report*", text: $viewModel.fileNamePattern)
                        .textFieldStyle(.roundedBorder)
                        .help("Wildcards: * (any chars), ? (single char). Separate with ;")

                    Button(action: { showPatternHelp() }) {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Pattern syntax help")
                }
            }

            // MARK: - Search In (directory)
            LabeledContent("Search in:") {
                HStack(spacing: 6) {
                    TextField("/Users/\u{2026}", text: $viewModel.searchDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button(action: { browseDirectory() }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Browse for directory")
                }
            }

            // MARK: - Find Text (content search)
            LabeledContent("Find text:") {
                TextField("Search inside file contents\u{2026}", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .help("Leave empty for filename-only search")
            }

            // MARK: - Options
            Section {
                Toggle("Case sensitive", isOn: $viewModel.caseSensitive)
                Toggle("Regular expressions", isOn: $viewModel.useRegex)
                Toggle("Include subdirectories", isOn: $viewModel.searchInSubdirectories)
                Toggle("Search in archives", isOn: $viewModel.searchInArchives)
            } header: {
                Text("Options")
            }
        }
        .formStyle(.grouped)
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
          *      \u{2014} matches any number of characters
          ?      \u{2014} matches exactly one character

        Examples:
          *.txt          \u{2014} all text files
          *.swift;*.java \u{2014} Swift and Java files
          report*        \u{2014} files starting with "report"
          photo?.jpg     \u{2014} photo1.jpg, photoA.jpg, etc.
          *.*            \u{2014} all files with extension

        Separate multiple patterns with semicolon (;)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

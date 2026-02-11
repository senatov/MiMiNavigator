// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 11.02.2026 — native macOS 26 HIG style
// Copyright © 2026 Senatov. All rights reserved.
// Description: General tab of Find Files — file name, search text, directory, options

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    // MARK: - Design Constants
    private enum Design {
        static let fieldMinWidth: CGFloat = 320
        static let labelWidth: CGFloat = 90
        static let spacing: CGFloat = 12
        static let cornerRadius: CGFloat = 6
        static let borderColor = Color(#colorLiteral(red: 0.75, green: 0.78, blue: 0.82, alpha: 0.5))
        static let focusBorderColor = Color.accentColor.opacity(0.6)
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

    // MARK: - Search For Section
    private var searchForSection: some View {
        LabeledContent("Search for:") {
            HStack(spacing: 8) {
                TextField("", text: $viewModel.fileNamePattern, prompt: Text("*.txt; *.swift; report*").foregroundStyle(.tertiary))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Design.cornerRadius)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.cornerRadius)
                            .strokeBorder(Design.borderColor, lineWidth: 1)
                    )
                    .frame(minWidth: Design.fieldMinWidth)
                    .help("Wildcards: * (any chars), ? (single char). Separate with ;")

                Button(action: { showPatternHelp() }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Pattern syntax help")
            }
        }
    }

    // MARK: - Search In Section
    private var searchInSection: some View {
        LabeledContent("Search in:") {
            HStack(spacing: 8) {
                TextField("", text: $viewModel.searchDirectory, prompt: Text("Select directory…").foregroundStyle(.tertiary))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Design.cornerRadius)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.cornerRadius)
                            .strokeBorder(Design.borderColor, lineWidth: 1)
                    )
                    .frame(minWidth: Design.fieldMinWidth)
                    .help("Directory to search in")

                Button(action: { browseDirectory() }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Browse…")
            }
        }
    }

    // MARK: - Find Text Section
    private var findTextSection: some View {
        LabeledContent("Find text:") {
            TextField("", text: $viewModel.searchText, prompt: Text("Search inside file contents…").foregroundStyle(.tertiary))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .strokeBorder(Design.borderColor, lineWidth: 1)
                )
                .frame(minWidth: Design.fieldMinWidth)
                .help("Leave empty for filename-only search")
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

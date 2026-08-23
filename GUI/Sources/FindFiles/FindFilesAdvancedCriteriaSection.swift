// FindFilesAdvancedCriteriaSection.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Independent base criteria for the Advanced Search module.

import AppKit
import SwiftUI

// MARK: - Advanced Search Criteria Section
struct FindFilesAdvancedCriteriaSection: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Advanced Search Criteria", systemImage: "slider.horizontal.3")
            HStack(spacing: 8) {
                Text("Name")
                    .frame(width: 72, alignment: .trailing)
                    .foregroundStyle(.secondary)
                Toggle("NOT", isOn: $viewModel.advancedSettings.invertFileNamePattern)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                TextField("File name pattern", text: $viewModel.advancedSettings.fileNamePattern)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                Text("Directory")
                    .frame(width: 72, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Directory path", text: $viewModel.advancedSettings.searchDirectory)
                    .textFieldStyle(.roundedBorder)
                Button(action: browseDirectory) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(ThemedButtonStyle())
            }
            HStack(spacing: 8) {
                Text("Find text")
                    .frame(width: 72, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Text to find inside files", text: $viewModel.advancedSettings.searchText)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 16) {
                Toggle("Case sensitive", isOn: $viewModel.advancedSettings.caseSensitive)
                Toggle("Regular expressions", isOn: $viewModel.advancedSettings.useRegex)
                Toggle("Include subdirectories", isOn: $viewModel.advancedSettings.searchInSubdirectories)
                Toggle("Search in archives", isOn: $viewModel.advancedSettings.searchInArchives)
            }
            .toggleStyle(.checkbox)
        }
        .font(.system(size: 12))
        .padding(DesignTokens.Spacing.group)
        .semanticSurface()
    }

    // MARK: - Browse Directory
    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.advancedSettings.searchDirectory = url.path
        }
    }
}

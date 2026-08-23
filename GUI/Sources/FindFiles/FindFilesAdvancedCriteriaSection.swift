// FindFilesAdvancedCriteriaSection.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Independent base criteria for the Advanced Search module.

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
                Toggle("NOT", isOn: settingBinding(\.invertFileNamePattern))
                    .toggleStyle(.checkbox)
                    .fixedSize()
                TextField("File name pattern", text: settingBinding(\.fileNamePattern))
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                Text("Directory")
                    .frame(width: 72, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Directory path", text: settingBinding(\.searchDirectory))
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
                TextField("Text to find inside files", text: settingBinding(\.searchText))
                    .onChange(of: viewModel.advancedSettings.searchText) {
                        viewModel.normalizeContentSearchSettings()
                    }
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 16) {
                Toggle("Case sensitive", isOn: settingBinding(\.caseSensitive))
                Toggle("Regular expressions", isOn: settingBinding(\.useRegex))
                Toggle("Include subdirectories", isOn: settingBinding(\.searchInSubdirectories))
                Toggle("Search in archives", isOn: settingBinding(\.searchInArchives))
            }
            .toggleStyle(.checkbox)
        }
        .font(.system(size: 12))
        .padding(DesignTokens.Spacing.group)
        .semanticSurface()
    }

    // MARK: - Browse Directory
    private func browseDirectory() {
        Task { @MainActor in
            let path = viewModel.advancedSettings.searchDirectory
            let initialURL = path.isEmpty ? nil : URL(fileURLWithPath: path)
            guard let url = await FindFilesOperationPresenter.chooseLocation(
                prompt: "Select",
                message: "Choose a directory to search",
                initialURL: initialURL,
                canChooseFiles: false
            ) else { return }
            viewModel.advancedSettings.searchDirectory = url.path
            viewModel.markAdvancedCriteriaEdited()
        }
    }

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<FindFilesSearchSettings, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.advancedSettings[keyPath: keyPath] },
            set: { value in
                viewModel.advancedSettings[keyPath: keyPath] = value
                viewModel.markAdvancedCriteriaEdited()
            }
        )
    }
}

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
        .font(DesignTokens.Typography.body)
        .padding(DesignTokens.Spacing.group)
        .semanticSurface()
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

// FindFilesTemplateSection.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search templates with directly editable criteria switches.

import FindFilesKit
import SwiftUI

// MARK: - Search Templates
struct FindFilesTemplateSection: View {
    @Bindable var viewModel: FindFilesViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Templates", systemImage: "shippingbox.fill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), alignment: .leading)], alignment: .leading, spacing: 8) {
                template("Large stale files", icon: "externaldrive.fill", preset: .largeStaleFiles, action: viewModel.applyLargeStaleFilesPreset)
                template("App leftovers", icon: "app.dashed", preset: .applicationLeftovers, action: viewModel.applyApplicationLeftoversPreset)
                template("Empty old folders", icon: "folder.badge.minus", preset: .emptyStaleFolders, action: viewModel.applyEmptyStaleFoldersPreset)
                template("Old downloads", icon: "arrow.down.circle", preset: .oldDownloads, action: viewModel.applyOldDownloadsPreset)
                template("Recently modified", icon: "clock", preset: .recentlyModified, action: viewModel.applyRecentlyModifiedPreset)
            }
            if viewModel.advancedSettings.activePreset != nil {
                criteria
            }
            Text("Turn criteria on or off; edit their values below. Selecting a template again restores its defaults.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if viewModel.advancedSettings.usesApplicationLeftovers {
                Text("Searches Library app data and excludes installed apps. Turn off App leftovers only to search the selected directory normally.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .semanticSurface()
    }
    private var criteria: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: 8) {
            Toggle("Item type", isOn: itemTypeEnabled)
            Toggle("Include subdirectories", isOn: $viewModel.advancedSettings.searchInSubdirectories)
            Toggle("Exclude system locations", isOn: $viewModel.advancedSettings.excludeSystemLocations)
            Toggle("Deletable only", isOn: $viewModel.advancedSettings.deletableOnly)
            Toggle("File size", isOn: $viewModel.advancedSettings.useSizeFilter)
                .disabled(viewModel.advancedSettings.itemTypeFilter == .foldersOnly)
            Toggle("Unused item age", isOn: $viewModel.advancedSettings.useStaleItemFilter)
            Toggle("Modification date", isOn: $viewModel.advancedSettings.useDateFilter)
            if viewModel.advancedSettings.activePreset == .emptyStaleFolders {
                Toggle("Empty folders only", isOn: $viewModel.advancedSettings.emptyFoldersOnly)
                    .disabled(viewModel.advancedSettings.itemTypeFilter != .foldersOnly)
            }
            if viewModel.advancedSettings.activePreset == .applicationLeftovers {
                Toggle("App leftovers only", isOn: leftoversEnabled)
            }
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 12))
    }
    private var itemTypeEnabled: Binding<Bool> {
        Binding(
            get: { viewModel.advancedSettings.itemTypeFilter != .filesAndFolders },
            set: { enabled in
                viewModel.advancedSettings.itemTypeFilter = enabled
                    ? (viewModel.advancedSettings.activePreset == .emptyStaleFolders ? .foldersOnly : .filesOnly)
                    : .filesAndFolders
            }
        )
    }
    private var leftoversEnabled: Binding<Bool> {
        Binding(
            get: { viewModel.advancedSettings.usesApplicationLeftovers },
            set: { enabled in
                viewModel.advancedSettings.usesApplicationLeftovers = enabled
                if enabled {
                    viewModel.advancedSettings.searchDirectory = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library", isDirectory: true).path
                }
            }
        )
    }
    // MARK: - Template Button
    private func template(_ title: String, icon: String, preset: FindFilesPreset, action: @escaping () -> Void) -> some View {
        let selected = viewModel.isPresetActive(preset)
        return Button(action: action) {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : icon)
        }
        .buttonStyle(ThemedButtonStyle())
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1))
    }
}

// FindFilesGeneralTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - General Tab
struct FindFilesGeneralTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        HStack(spacing: 0) {
            searchCriteria
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .padding(.vertical, 10)
            ScrollView {
                options
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DialogColors.base.opacity(0.96))
    }

    // MARK: - Search Criteria
    private var searchCriteria: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Search Criteria", icon: "magnifyingglass", color: .blue)
            VStack(spacing: 10) {
                compactField(label: "Search for:", icon: "doc.text", iconColor: .orange) {
                    HStack(spacing: 6) {
                        Toggle("NOT", isOn: $viewModel.invertFileNamePattern)
                            .toggleStyle(.checkbox)
                            .fixedSize()
                            .help("Find names that do not match the pattern")
                        SearchHistoryComboBox(
                            text: $viewModel.fileNamePattern,
                            historyKey: .fileNamePattern,
                            placeholder: "File name pattern",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: showPatternHelp) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Pattern syntax help")
                    }
                }
                compactField(label: "Search in:", icon: "folder.fill", iconColor: .blue) {
                    HStack(spacing: 6) {
                        SearchHistoryComboBox(
                            text: $viewModel.searchDirectory,
                            historyKey: .searchDirectory,
                            placeholder: "Directory path",
                            onSubmit: { viewModel.startSearch() }
                        )
                        .frame(height: 24)
                        Button(action: browseDirectory) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(ThemedButtonStyle())
                        .controlSize(.regular)
                        .help("Browse…")
                    }
                }
                compactField(label: "Find text:", icon: "text.magnifyingglass", iconColor: .purple) {
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
            .padding(.bottom, 12)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Options
    private var options: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Options", icon: "gearshape", color: .secondary)
            VStack(spacing: 0) {
                optionToggle(
                    title: "Case sensitive",
                    icon: "textformat",
                    iconColor: .indigo,
                    isOn: $viewModel.caseSensitive
                )
                optionDivider()
                optionToggle(
                    title: "Regular expressions",
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .teal,
                    isOn: $viewModel.useRegex
                )
                optionDivider()
                optionToggle(
                    title: "Include subdirectories",
                    icon: "folder.fill.badge.gearshape",
                    iconColor: .blue,
                    isOn: $viewModel.searchInSubdirectories
                )
                optionDivider()
                optionToggle(
                    title: "Search in archives",
                    icon: "archivebox.fill",
                    iconColor: .brown,
                    isOn: $viewModel.searchInArchives
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.label)
                .foregroundStyle(color)
            Text(title)
                .font(DesignTokens.Typography.sectionTitle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Option Row Divider (inside options block)
    private func optionDivider() -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 44)
    }

    // MARK: - Compact Field
    private func compactField<Content: View>(
        label: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 18, alignment: .center)
                Text(label)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    // MARK: - Option Toggle Row
    private func optionToggle(
        title: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.label)
                .foregroundStyle(iconColor)
                .frame(width: 22, alignment: .center)
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isOn.wrappedValue ? iconColor.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isOn.wrappedValue ? iconColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Browse
    private func browseDirectory() {
        Task { @MainActor in
            let initialURL = viewModel.searchDirectory.isEmpty ? nil : URL(fileURLWithPath: viewModel.searchDirectory)
            guard let url = await FindFilesOperationPresenter.chooseLocation(
                prompt: "Select",
                message: "Choose directory, file, or archive to search in",
                initialURL: initialURL,
                canChooseFiles: true
            ) else { return }
            viewModel.searchDirectory = url.path
        }
    }

    // MARK: - Pattern Help
    private func showPatternHelp() {
        InAppNoticeCenter.shared.showBanner(
            title: "File Name Pattern Syntax",
            message: "Use * for any number of characters and ? for one character. Separate multiple patterns with semicolons, for example: *.swift;*.java",
            scope: .findFiles,
            systemImage: "questionmark.circle.fill",
            tint: .blue
        )
    }
}

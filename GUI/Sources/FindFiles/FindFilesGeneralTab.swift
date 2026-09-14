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
        HStack(alignment: .top, spacing: 12) {
            searchCriteria
                .frame(maxWidth: .infinity, alignment: .top)
            ScrollView {
                options
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
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
            .padding(.bottom, 14)
        }
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .padding(.bottom, 14)
        }
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(.vertical, 11)
        .background(DialogColors.stripe.opacity(0.24))
        .overlay(alignment: .bottom) {
            Rectangle().fill(DialogColors.border.opacity(0.4)).frame(height: 0.5)
        }
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
                .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.075) : Color.clear)
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(DialogColors.light.opacity(0.94))
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(DialogColors.border.opacity(0.62), lineWidth: 0.75)
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

// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced tab of Find Files.

import SwiftUI
import FindFilesKit
// MARK: - Advanced Tab
struct FindFilesAdvancedTab: View {
    @Bindable var viewModel: FindFilesViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                FindFilesTabButton(title: "Templates", icon: "shippingbox", isSelected: viewModel.usesTemplateEditor) {
                    viewModel.selectAdvancedEditor(templates: true)
                }
                FindFilesTabButton(title: "Manual", icon: "slider.horizontal.3", isSelected: !viewModel.usesTemplateEditor) {
                    viewModel.selectAdvancedEditor(templates: false)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.usesTemplateEditor {
                        FindFilesTemplateSection(viewModel: viewModel)
                    } else {
                        FindFilesAdvancedCriteriaSection(viewModel: viewModel)
                        scopeSection
                        filtersSection
                        infoSection
                    }
                }
                .padding(10)
            }
        }
        .onChange(of: viewModel.advancedSettings.itemTypeFilter) {
            if viewModel.advancedSettings.itemTypeFilter == .foldersOnly {
                viewModel.advancedSettings.useSizeFilter = false
            } else {
                viewModel.advancedSettings.emptyFoldersOnly = false
            }
        }
    }
    private var scopeSection: some View {
        advancedCard(icon: "folder.badge.gearshape", title: "Scope", tint: .teal) {
            VStack(spacing: 0) {
                itemTypeRow()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { scopeOptions }
                    VStack(spacing: 2) { scopeOptions }
                }
                if viewModel.advancedSettings.itemTypeFilter == .foldersOnly {
                    optionRow(
                        title: "Empty folders only",
                        detail: "Return folders that contain no items",
                        icon: "folder.badge.minus",
                        tint: .orange,
                        isOn: $viewModel.advancedSettings.emptyFoldersOnly
                    )
                }
            }
        }
    }
    private var scopeOptions: some View {
        Group {
            optionRow(title: "Exclude system locations", detail: "Skip protected macOS and cloud paths", icon: "macwindow.badge.plus", tint: .blue,
                      isOn: $viewModel.advancedSettings.excludeSystemLocations)
                .frame(minWidth: 300)
            optionRow(title: "Deletable items only", detail: "Only return items you can remove", icon: "trash", tint: .orange,
                      isOn: $viewModel.advancedSettings.deletableOnly)
                .frame(minWidth: 300)
        }
    }

    private var infoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text("Content search scans text files only. Archive search supports ZIP, 7z, TAR, GZ, BZ2, XZ, RAR, JAR and 40+ other formats.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    func advancedCard<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.label)
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DialogColors.light.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.62), lineWidth: 0.75)
        )
    }

    func optionRow(
        title: String,
        detail: String,
        icon: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.055) : Color.clear)
        )
    }

    private func itemTypeRow() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.2x2").foregroundStyle(.teal).frame(width: 18)
            Text("Item type").font(.body)
            Picker("", selection: $viewModel.advancedSettings.itemTypeFilter) {
                ForEach(FindFilesItemTypeFilter.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 370)
            Spacer(minLength: 0)
        }
    }

}

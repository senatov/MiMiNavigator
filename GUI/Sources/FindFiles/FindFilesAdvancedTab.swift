// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced tab of Find Files.

import SwiftUI

// MARK: - Advanced Tab
struct FindFilesAdvancedTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                presetSection
                scopeSection
                sizeSection
                dateSection
                infoSection
            }
            .padding(12)
        }
        .background(DialogColors.base.opacity(0.96))
        .onChange(of: viewModel.itemTypeFilter) {
            if viewModel.itemTypeFilter == .foldersOnly {
                viewModel.useSizeFilter = false
            } else {
                viewModel.emptyFoldersOnly = false
            }
        }
    }

    private var presetSection: some View {
        advancedCard(icon: "shippingbox.fill", title: "Templates", tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        viewModel.applyLargeStaleFilesPreset()
                    } label: {
                        Label("Large stale files", systemImage: "externaldrive.fill.badge.exclamationmark")
                    }
                    .buttonStyle(ThemedButtonStyle())
                    Button {
                        viewModel.applyApplicationLeftoversPreset()
                    } label: {
                        Label("App leftovers", systemImage: "app.dashed")
                    }
                    .buttonStyle(ThemedButtonStyle())
                    Button {
                        viewModel.applyEmptyStaleFoldersPreset()
                    } label: {
                        Label("Empty old folders", systemImage: "folder.badge.minus")
                    }
                    .buttonStyle(ThemedButtonStyle())
                }
                Text("Templates set safe scopes and editable age/size filters; every result is only a candidate for review.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scopeSection: some View {
        advancedCard(icon: "folder.badge.gearshape", title: "Scope", tint: .teal) {
            VStack(spacing: 0) {
                itemTypeRow()
                rowDivider()
                optionRow(
                    title: "Exclude macOS and app-support locations",
                    detail: "Skip protected OS roots, but keep user-controlled app data locations",
                    icon: "macwindow.badge.plus",
                    tint: .indigo,
                    isOn: $viewModel.excludeSystemLocations
                )
                rowDivider()
                optionRow(
                    title: "Return deletable items only",
                    detail: "Skip matches that the current user cannot remove",
                    icon: "trash",
                    tint: .red,
                    isOn: $viewModel.deletableOnly
                )
            }
        }
    }

    private var sizeSection: some View {
        advancedCard(icon: "ruler.fill", title: "File Size", tint: .orange) {
            VStack(spacing: 8) {
                optionRow(
                    title: "Filter by size",
                    detail: "Only match files within the size range",
                    icon: "arrow.up.arrow.down",
                    tint: .orange,
                    isOn: $viewModel.useSizeFilter
                )

                if viewModel.useSizeFilter {
                    HStack(spacing: 8) {
                        Text("From")
                            .foregroundStyle(.secondary)
                        TextField("min", text: $viewModel.fileSizeMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("to")
                            .foregroundStyle(.secondary)
                        TextField("max", text: $viewModel.fileSizeMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Picker("", selection: $viewModel.fileSizeUnit) {
                            ForEach(FindFilesSizeUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .padding(.leading, 34)
                }
            }
        }
    }

    private var dateSection: some View {
        advancedCard(icon: "calendar", title: "Dates", tint: .red) {
            VStack(spacing: 10) {
                optionRow(
                    title: "Filter by modification date",
                    detail: "Only match files modified within the date range",
                    icon: "calendar.badge.clock",
                    tint: .purple,
                    isOn: $viewModel.useDateFilter
                )

                if viewModel.useDateFilter {
                    HStack(spacing: 8) {
                        Text("From")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.dateFrom, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.dateTo, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                    }
                    .padding(.leading, 34)
                }

                rowDivider()

                optionRow(
                    title: "Unused item age",
                    detail: "Choose date or age, then apply it to modified time, access time, or both",
                    icon: "clock.badge.xmark",
                    tint: .red,
                    isOn: $viewModel.useStaleItemFilter
                )

                if viewModel.useStaleItemFilter {
                    staleCriteriaControls
                    .padding(.leading, 34)
                }
            }
        }
    }

    private var staleCriteriaControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Match")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                Picker("", selection: $viewModel.staleTimestampFilter) {
                    ForEach(FindFilesTimestampFilter.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("By")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                Picker("", selection: $viewModel.staleCriterionMode) {
                    ForEach(FindFilesStaleCriterionMode.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)

                switch viewModel.staleCriterionMode {
                case .date:
                    Text("since")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.staleSinceDate, displayedComponents: .date)
                        .labelsHidden()
                case .age:
                    Text("older than")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("amount", text: $viewModel.staleAgeAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 82)
                    Picker("", selection: $viewModel.staleAgeUnit) {
                        ForEach(FindFilesAgeUnit.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                Spacer()
            }
            if viewModel.staleCriterionMode == .age {
                HStack(spacing: 6) {
                    Text("Quick")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                    ForEach([1, 2, 3], id: \.self) { years in
                        Button("\(years) year\(years == 1 ? "" : "s")") {
                            viewModel.staleAgeAmount = String(years)
                            viewModel.staleAgeUnit = .years
                        }
                        .buttonStyle(ThemedButtonStyle())
                        .controlSize(.small)
                    }
                    Spacer()
                }
            }
        }
    }

    private var infoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text("Content search scans text files only. Archive search supports ZIP, 7z, TAR, GZ, BZ2, XZ, RAR, JAR and 40+ other formats.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func advancedCard<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DialogColors.light.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.75), lineWidth: 1)
        )
    }

    private func optionRow(
        title: String,
        detail: String,
        icon: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private func itemTypeRow() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.folder")
                .font(.system(size: 14))
                .foregroundStyle(.teal)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Item type")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text("Choose whether folders can appear in the results")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $viewModel.itemTypeFilter) {
                ForEach(FindFilesItemTypeFilter.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 330)
        }
        .padding(.vertical, 2)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(DialogColors.border.opacity(0.35))
            .frame(height: 0.5)
            .padding(.leading, 32)
    }
}

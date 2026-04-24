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
    }

    private var presetSection: some View {
        advancedCard(icon: "shippingbox.fill", title: "Templates", tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        viewModel.applyPotentialBallastPreset()
                    } label: {
                        Label("Potential user ballast", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(ThemedButtonStyle())
                    .controlSize(.large)
                    .help("Configure a whole-disk ballast search and enable the editable age fields below.")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Searches from /, includes files and folders, skips protected OS roots.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Fill the age fields here before starting the search.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }

                if viewModel.useStaleItemFilter {
                    staleCriteriaControls
                    .padding(.leading, 34)
                }
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
                    detail: "Byte range",
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
                            .frame(width: 100)
                        Text("to")
                            .foregroundStyle(.secondary)
                        TextField("max", text: $viewModel.fileSizeMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("bytes")
                            .foregroundStyle(.tertiary)
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
                    title: "Unused item age",
                    detail: "Choose date or age, then apply it to modified time, access time, or both",
                    icon: "calendar.badge.clock",
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
                    .frame(width: 230)
                }
                Spacer()
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
                .strokeBorder(DialogColors.border.opacity(0.45), lineWidth: 0.5)
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
            .frame(width: 220)
        }
        .padding(.vertical, 2)
    }

    private func ageFilterRow(
        title: String,
        icon: String,
        tint: Color,
        isOn: Binding<Bool>,
        amount: Binding<String>,
        unit: Binding<FindFilesAgeUnit>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            optionRow(title: title, detail: "User-defined age threshold", icon: icon, tint: tint, isOn: isOn)
            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    TextField("amount", text: amount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 82)
                    Picker("", selection: unit) {
                        ForEach(FindFilesAgeUnit.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    Spacer()
                }
                .padding(.leading, 34)
            }
        }
    }

    private func compactAgeEntryRow(
        label: String,
        amount: Binding<String>,
        unit: Binding<FindFilesAgeUnit>
    ) -> some View {
        HStack(spacing: 8) {
            Text("Not \(label.lowercased()) for at least")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .trailing)
            TextField("amount", text: amount)
                .textFieldStyle(.roundedBorder)
                .frame(width: 82)
            Picker("", selection: unit) {
                ForEach(FindFilesAgeUnit.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 160)
            Spacer()
        }
    }

    private func datePickerRow(label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
            Spacer()
        }
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(DialogColors.border.opacity(0.35))
            .frame(height: 0.5)
            .padding(.leading, 32)
    }
}

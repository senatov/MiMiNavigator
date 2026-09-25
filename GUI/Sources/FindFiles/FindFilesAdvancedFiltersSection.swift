// FindFilesAdvancedFiltersSection.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import FindFilesKit
import SwiftUI

// MARK: - Compact Advanced Filters
extension FindFilesAdvancedTab {
    var filtersSection: some View {
        advancedCard(icon: "line.3.horizontal.decrease", title: "Filters", tint: .orange) {
            VStack(alignment: .leading, spacing: 7) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        sizeControls.frame(minWidth: 420)
                        dateControls.frame(minWidth: 370)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        sizeControls
                        dateControls
                    }
                }
                rowDivider()
                optionRow(title: "Unused item age", detail: "Match modified time, access time, or both", icon: "clock.badge.xmark", tint: .orange,
                          isOn: $viewModel.advancedSettings.useStaleItemFilter)
                if viewModel.advancedSettings.useStaleItemFilter {
                    staleCriteriaControls.padding(.leading, 26)
                }
            }
        }
    }

    // MARK: - Size and Date
    private var sizeControls: some View {
        VStack(alignment: .leading, spacing: 5) {
            optionRow(title: "File size", detail: "Limit results by size", icon: "ruler.fill", tint: .orange,
                      isOn: $viewModel.advancedSettings.useSizeFilter)
            if viewModel.advancedSettings.useSizeFilter {
                HStack(spacing: 5) {
                    Text("From").foregroundStyle(.secondary)
                    DialogTextField("min", text: $viewModel.advancedSettings.fileSizeMin)
                        .textFieldStyle(.roundedBorder).frame(width: 64)
                    Text("to").foregroundStyle(.secondary)
                    DialogTextField("max", text: $viewModel.advancedSettings.fileSizeMax)
                        .textFieldStyle(.roundedBorder).frame(width: 64)
                    Picker("Unit", selection: $viewModel.advancedSettings.fileSizeUnit) {
                        ForEach(FindFilesSizeUnit.allCases) { unit in Text(unit.label).tag(unit) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 150)
                }
                .padding(.leading, 26)
            }
        }
    }

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 5) {
            optionRow(title: "Modified date", detail: "Only files within a date range", icon: "calendar.badge.clock", tint: .blue,
                      isOn: $viewModel.advancedSettings.useDateFilter)
            if viewModel.advancedSettings.useDateFilter {
                HStack(spacing: 5) {
                    Text("From").foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.advancedSettings.dateFrom, displayedComponents: .date).labelsHidden()
                    Text("to").foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.advancedSettings.dateTo, displayedComponents: .date).labelsHidden()
                }
                .padding(.leading, 26)
            }
        }
    }

    // MARK: - Unused Item Criteria
    private var staleCriteriaControls: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text("Match").foregroundStyle(.secondary)
                Picker("", selection: $viewModel.advancedSettings.staleTimestampFilter) {
                    ForEach(FindFilesTimestampFilter.allCases) { value in Text(value.label).tag(value) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 248)
                Text("By").foregroundStyle(.secondary)
                Picker("", selection: $viewModel.advancedSettings.staleCriterionMode) {
                    ForEach(FindFilesStaleCriterionMode.allCases) { value in Text(value.label).tag(value) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 136)
            }
            HStack(spacing: 6) {
                switch viewModel.advancedSettings.staleCriterionMode {
                case .date:
                    Text("Since").foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.advancedSettings.staleSinceDate, displayedComponents: .date).labelsHidden()
                case .age:
                    Text("Older than").foregroundStyle(.secondary)
                    DialogTextField("amount", text: $viewModel.advancedSettings.staleAgeAmount)
                        .textFieldStyle(.roundedBorder).frame(width: 70)
                    Picker("", selection: $viewModel.advancedSettings.staleAgeUnit) {
                        ForEach(FindFilesAgeUnit.allCases) { value in Text(value.label).tag(value) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 170)
                    Text("Quick:").foregroundStyle(.secondary).padding(.leading, 8)
                    ForEach([1, 2, 3], id: \.self) { years in
                        Button("\(years)y") {
                            viewModel.advancedSettings.staleAgeAmount = String(years)
                            viewModel.advancedSettings.staleAgeUnit = .years
                        }
                        .buttonStyle(ThemedButtonStyle(isSelected: isSelectedYear(years)))
                    }
                }
            }
        }
        .controlSize(.small)
        .font(.body)
    }
}

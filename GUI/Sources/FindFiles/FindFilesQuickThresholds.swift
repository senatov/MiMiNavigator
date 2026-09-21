// FindFilesQuickThresholds.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Quick age and minimum-size choices backed by the search criteria.

import SwiftUI
import FindFilesKit

// MARK: - Quick Search Thresholds
struct FindFilesQuickThresholds: View {
    @Binding var settings: FindFilesSearchSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("Older than", isOn: $settings.useStaleItemFilter)
                    .frame(width: 125, alignment: .leading)
                Picker("Older than", selection: ageSelection) {
                    Text("1 month").tag(Optional(1))
                    Text("3 months").tag(Optional(3))
                    Text("6 months").tag(Optional(6))
                    Text("1 year").tag(Optional(12))
                    Text("2 years").tag(Optional(24))
                }
                .labelsHidden()
                .frame(width: 130)
                .help("Applies to the modified time, access time, or both specified by the selected template. Choosing a value enables the age filter.")
            }
            HStack(spacing: 10) {
                Toggle("Minimum size", isOn: $settings.useSizeFilter)
                    .frame(width: 125, alignment: .leading)
                Picker("Minimum size", selection: sizeSelection) {
                    ForEach([50, 100, 250, 500, 1024], id: \.self) { size in
                        Text(size == 1024 ? "≥1 GB" : "≥\(size) MB").tag(Optional(size))
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                .help("Choosing a minimum size enables the size filter and clears the upper limit.")
            }
            .disabled(settings.itemTypeFilter == .foldersOnly)
        }
        .toggleStyle(.checkbox)
        .pickerStyle(.menu)
        .controlSize(.small)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    // MARK: - Age Selection
    private var ageSelection: Binding<Int?> {
        Binding(
            get: {
                guard settings.useStaleItemFilter, settings.staleCriterionMode == .age,
                    let amount = Int(settings.staleAgeAmount) else { return nil }
                let months = settings.staleAgeUnit == .years ? amount * 12 : amount
                guard settings.staleAgeUnit != .days, [1, 3, 6, 12, 24].contains(months) else { return nil }
                return months
            },
            set: { months in
                guard let months else { return }
                settings.staleAgeAmount = String(months >= 12 ? months / 12 : months)
                settings.staleAgeUnit = months >= 12 ? .years : .months
                settings.staleCriterionMode = .age
                settings.useStaleItemFilter = true
            }
        )
    }
    // MARK: - Size Selection
    private var sizeSelection: Binding<Int?> {
        Binding(
            get: {
                guard settings.useSizeFilter, settings.fileSizeMax.isEmpty,
                    let amount = Double(settings.fileSizeMin) else { return nil }
                let megabytes = amount * Double(settings.fileSizeUnit.multiplier) / Double(FindFilesSizeUnit.megabytes.multiplier)
                return [50, 100, 250, 500, 1024].first { Double($0) == megabytes }
            },
            set: { size in
                guard let size else { return }
                settings.fileSizeMin = size == 1024 ? "1" : String(size)
                settings.fileSizeUnit = size == 1024 ? .gigabytes : .megabytes
                settings.fileSizeMax = ""
                settings.useSizeFilter = true
            }
        )
    }
}

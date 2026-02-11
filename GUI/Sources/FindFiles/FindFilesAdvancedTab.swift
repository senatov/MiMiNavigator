// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 11.02.2026 — native macOS 26 Form style
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced tab of Find Files — size filter, date filter

import SwiftUI

// MARK: - Advanced Tab
struct FindFilesAdvancedTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        Form {
            // MARK: - Size Filter
            Section("File Size") {
                Toggle("Filter by size", isOn: $viewModel.useSizeFilter)

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
                    }
                }
            }

            // MARK: - Date Filter
            Section("Modification Date") {
                Toggle("Filter by date", isOn: $viewModel.useDateFilter)

                if viewModel.useDateFilter {
                    DatePicker("From:", selection: $viewModel.dateFrom, displayedComponents: .date)
                    DatePicker("To:", selection: $viewModel.dateTo, displayedComponents: .date)
                }
            }

            // MARK: - Info
            Section {
                Label(
                    "Content search scans text files only. Binary files are skipped. Archive search supports ZIP, 7z, TAR, GZ, BZ2.",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}

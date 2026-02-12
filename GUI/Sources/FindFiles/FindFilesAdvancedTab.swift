// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 12.02.2026 — clean HIG 26 style
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
                        TextField("min", text: $viewModel.fileSizeMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("to")
                        TextField("max", text: $viewModel.fileSizeMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("bytes")
                            .foregroundStyle(.secondary)
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
                    "Content search scans text files only. Binary files are skipped. Archive search supports ZIP, 7z, TAR, GZ, BZ2, XZ, RAR, JAR and 40+ other formats.",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}

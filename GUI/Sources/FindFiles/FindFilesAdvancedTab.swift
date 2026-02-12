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
            Section {
                Toggle(isOn: $viewModel.useSizeFilter) {
                    Text("Filter by size").font(.system(size: 13))
                }

                if viewModel.useSizeFilter {
                    HStack(spacing: 8) {
                        Text("From")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)

                        TextField("min", text: $viewModel.fileSizeMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        Text("to")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)

                        TextField("max", text: $viewModel.fileSizeMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        Text("bytes")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(#colorLiteral(red: 0.45, green: 0.47, blue: 0.52, alpha: 1)))
                    }
                }
            } header: {
                Text("File Size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // MARK: - Date Filter
            Section {
                Toggle(isOn: $viewModel.useDateFilter) {
                    Text("Filter by date").font(.system(size: 13))
                }

                if viewModel.useDateFilter {
                    DatePicker(selection: $viewModel.dateFrom, displayedComponents: .date) {
                        Text("From:").font(.system(size: 13, weight: .medium))
                    }
                    DatePicker(selection: $viewModel.dateTo, displayedComponents: .date) {
                        Text("To:").font(.system(size: 13, weight: .medium))
                    }
                }
            } header: {
                Text("Modification Date")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // MARK: - Info
            Section {
                Label(
                    "Content search scans text files only. Binary files are skipped. Archive search supports ZIP, 7z, TAR, GZ, BZ2.",
                    systemImage: "info.circle"
                )
                .foregroundStyle(Color(#colorLiteral(red: 0.35, green: 0.38, blue: 0.45, alpha: 1)))
                .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}

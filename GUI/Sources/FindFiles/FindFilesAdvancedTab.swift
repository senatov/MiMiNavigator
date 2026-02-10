// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced tab of Find Files — size filter, date filter, extended options

import SwiftUI

// MARK: - Advanced Tab
struct FindFilesAdvancedTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Size Filter
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Filter by size", isOn: $viewModel.useSizeFilter)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .medium))

                    if viewModel.useSizeFilter {
                        HStack(spacing: 8) {
                            Text("From:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)

                            TextField("min bytes", text: $viewModel.fileSizeMin)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .frame(width: 120)

                            Text("To:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            TextField("max bytes", text: $viewModel.fileSizeMax)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .frame(width: 120)

                            Text("bytes")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(4)
            }

            // MARK: - Date Filter
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Filter by date", isOn: $viewModel.useDateFilter)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .medium))

                    if viewModel.useDateFilter {
                        HStack(spacing: 8) {
                            Text("From:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)

                            DatePicker("", selection: $viewModel.dateFrom, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 140)

                            Text("To:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            DatePicker("", selection: $viewModel.dateTo, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 140)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(4)
            }

            // MARK: - Info Section
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                Text("Content search scans text files only. Binary files are skipped automatically. Archive search supports ZIP, 7z, TAR, GZ, BZ2.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Preview
#Preview("Advanced Tab") {
    let vm = FindFilesViewModel()
    vm.useSizeFilter = true
    vm.useDateFilter = true

    return FindFilesAdvancedTab(viewModel: vm)
        .padding()
        .frame(width: 600)
}

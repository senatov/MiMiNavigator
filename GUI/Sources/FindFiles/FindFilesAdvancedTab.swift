// FindFilesAdvancedTab.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced tab of Find Files — size filter, date filter

import SwiftUI

// MARK: - Advanced Tab
struct FindFilesAdvancedTab: View {
    @Bindable var viewModel: FindFilesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - File Size Section
            sectionHeader(title: "File Size", icon: "ruler.fill", color: .orange)

            VStack(spacing: 8) {
                optionToggle(
                    title: "Filter by size",
                    icon: "arrow.up.arrow.down",
                    iconColor: .orange,
                    isOn: $viewModel.useSizeFilter
                )

                if viewModel.useSizeFilter {
                    HStack(spacing: 8) {
                        Text("From")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        TextField("min", text: $viewModel.fileSizeMin)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("to")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        TextField("max", text: $viewModel.fileSizeMax)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("bytes")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            sectionDivider()

            // MARK: - Date Section
            sectionHeader(title: "Modification Date", icon: "calendar", color: .red)

            VStack(spacing: 8) {
                optionToggle(
                    title: "Filter by date",
                    icon: "calendar.badge.clock",
                    iconColor: .red,
                    isOn: $viewModel.useDateFilter
                )

                if viewModel.useDateFilter {
                    VStack(spacing: 6) {
                        HStack {
                            Text("From:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            DatePicker("", selection: $viewModel.dateFrom, displayedComponents: .date)
                                .labelsHidden()
                        }
                        HStack {
                            Text("To:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            DatePicker("", selection: $viewModel.dateTo, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            sectionDivider()

            // MARK: - Info Section
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("Content search scans text files only. Binary files are skipped. Archive search supports ZIP, 7z, TAR, GZ, BZ2, XZ, RAR, JAR and 40+ other formats.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Section Divider

    private func sectionDivider() -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    // MARK: - Option Toggle

    private func optionToggle(
        title: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 22, alignment: .center)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

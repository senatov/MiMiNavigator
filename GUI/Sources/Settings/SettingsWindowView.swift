// SettingsWindowView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root view of the Settings floating panel.
//   Left sidebar (ForkLift/Edge style) + right content area.

import SwiftUI

// MARK: - SettingsWindowView
struct SettingsWindowView: View {

    let onDismiss: () -> Void

    @State private var selectedSection: SettingsSection = .general
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body
    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 220)

            contentPane
                .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 440)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search bar (ForkLift style)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Text("Search")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) {
                Divider()
            }

            // Section list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarRow(section)
                    }
                }
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)

            // Bottom "..." menu (ForkLift style)
            HStack {
                Button {
                    // reserved: import/export/reset settings
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(10)
                Spacer()
            }
            .overlay(alignment: .top) { Divider() }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.96))
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selectedSection == section ? .white : Color.accentColor)
                .frame(width: 20)

            Text(section.rawValue)
                .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                .foregroundStyle(selectedSection == section ? .white : Color.primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selectedSection == section ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selectedSection = section } }
        .padding(.horizontal, 6)
    }

    // MARK: - Content Pane

    @ViewBuilder
    private var contentPane: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Section title bar
                    HStack {
                        Image(systemName: selectedSection.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        Text(selectedSection.rawValue)
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Section content
                    Group {
                        switch selectedSection {
                        case .general:     SettingsGeneralPane()
                        case .colors:      SettingsColorsPane()
                        case .panels:      SettingsPanelsPane()
                        case .tabs:        SettingsTabsPane()
                        case .archives:    SettingsArchivesPane()
                        case .network:     SettingsNetworkPane()
                        case .diffTool:    SettingsDiffToolPane()
                        case .permissions: SettingsPermissionsPane()
                        case .hotkeys:     SettingsHotkeysPane()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

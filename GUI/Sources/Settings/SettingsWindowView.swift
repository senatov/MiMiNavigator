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
    @State private var themeStore = ColorThemeStore.shared
    @Environment(\.colorScheme) private var colorScheme

    private var dialogBgColor: Color {
        let store = ColorThemeStore.shared
        if !store.hexDialogBackground.isEmpty, let c = Color(hex: store.hexDialogBackground) {
            return c
        }
        return store.activeTheme.dialogBackground
    }

    // MARK: - Body
    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 220)

            contentPane
                .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 440)
        .background(dialogBgColor.ignoresSafeArea())
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
        .background(DialogColors.base.opacity(0.96))
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
            dialogBgColor

            if selectedSection == .hotkeys {
                // Hotkeys has its own HSplitView + ScrollView — fill the whole area
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitleBar
                    Divider().padding(.horizontal, 24).padding(.bottom, 0)
                    SettingsHotkeysPane()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitleBar
                        Divider().padding(.horizontal, 24).padding(.bottom, 16)
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
                            case .hotkeys:     EmptyView() // handled above
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var sectionTitleBar: some View {
        HStack {
            Image(systemName: selectedSection.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DialogColors.accent)
            Text(selectedSection.rawValue)
                .font(.system(size: 17, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

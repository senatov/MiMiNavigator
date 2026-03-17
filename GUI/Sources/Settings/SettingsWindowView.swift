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
    @State private var coordinator = SettingsCoordinator.shared
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
        .onAppear {
            if let pending = coordinator.pendingSection {
                selectedSection = pending
                coordinator.pendingSection = nil
            }
        }
        .onChange(of: coordinator.pendingSection) { _, newValue in
            if let section = newValue {
                selectedSection = section
                coordinator.pendingSection = nil
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Text("Settings")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            // Section list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingsSection.allCases) { section in
                        // Group header divider (e.g. "Colors", "Layout")
                        if let header = section.groupHeader {
                            groupLabel(header)
                        }
                        sidebarRow(section)
                    }
                }
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)

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

    // MARK: - Group label (Nova-style section divider)
    private func groupLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "paintpalette")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 3)
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        let indent: CGFloat = section.isSubItem ? 14 : 0
        return HStack(spacing: 6) {
            Image(systemName: section.icon)
                .font(.system(size: section.isSubItem ? 12 : 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 18)
            Text(section.label)
                .font(.system(size: section.isSubItem ? 12 : 13,
                              weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.primary)
            Spacer()
        }
        .padding(.leading, 10 + indent)
        .padding(.trailing, 10)
        .padding(.vertical, section.isSubItem ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
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
                            case .general:            SettingsGeneralPane()
                            case .colorsPanels:       SettingsColorsPanelsPane()
                            case .colorsChrome:       SettingsColorsChromePane()
                            case .colorsBreadcrumb:   SettingsColorsBreadcrumbPane()
                            case .colorsButtons:      SettingsColorsButtonsPane()
                            case .panels:             SettingsPanelsPane()
                            case .tabs:               SettingsTabsPane()
                            case .archives:           SettingsArchivesPane()
                            case .network:            SettingsNetworkPane()
                            case .diffTool:           SettingsDiffToolPane()
                            case .permissions:        SettingsPermissionsPane()
                            case .hotkeys:            EmptyView()
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

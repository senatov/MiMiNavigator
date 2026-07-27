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

    @State private var selectedSection: SettingsSection = Self.restoredSection()
    @State private var coordinator = SettingsCoordinator.shared
    private static let selectedSectionDefaultsKey = "SettingsWindowView.selectedSection"

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
        .keyboardFocusSection()
        .background(.ultraThinMaterial)
        .background(dialogBgColor.opacity(0.72).ignoresSafeArea())
        .onAppear {
            if let pending = coordinator.pendingSection {
                selectedSection = pending
                coordinator.pendingSection = nil
            }
            persistSelectedSection()
        }
        .onChange(of: coordinator.pendingSection) { _, newValue in
            if let section = newValue {
                selectedSection = section
                coordinator.pendingSection = nil
            }
        }
        .onChange(of: selectedSection) { _, _ in
            persistSelectedSection()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
                    .font(.system(size: 12))
                Text("Settings")
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
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
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                }
                .buttonStyle(.plain)
                .padding(10)
                Spacer()
            }
            .overlay(alignment: .top) { Divider() }
        }
        .background(.regularMaterial)
    }

    // MARK: - Group label (Nova-style section divider)
    private func groupLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "paintpalette")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(SettingsVisualStyle.secondaryText)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(SettingsVisualStyle.secondaryText)
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
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedSection = section }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: section.isSubItem ? 12 : 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                    .frame(width: 18)
                Text(section.label)
                    .font(.system(size: section.isSubItem ? 12 : 13,
                                  weight: isSelected ? .light : .regular))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                Spacer()
            }
            .padding(.leading, 10 + indent)
            .padding(.trailing, 10)
            .padding(.vertical, section.isSubItem ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.88) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardFocusable()
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
                            case .cloudLink:          SettingsCloudLinkPane()
                            case .diffTool:           SettingsDiffToolPane()
                            case .progress:           SettingsProgressPane()
                            case .externalTools:      SettingsExternalToolsPane()
                            case .permissions:        SettingsPermissionsPane()
                            case .hotkeys:            EmptyView()
                            }
                        }
                        .keyboardFocusSection()
                        .groupBoxStyle(SettingsFluentGroupBoxStyle())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var sectionTitleBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                SettingsVisualStyle.accent.opacity(0.82),
                                SettingsVisualStyle.accent.opacity(0.52)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.42), lineWidth: 0.5)
                    }
                    .shadow(color: SettingsVisualStyle.accent.opacity(0.18), radius: 6, y: 3)
                Image(systemName: selectedSection.icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                Text(selectedSection.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - State Persistence
    private static func restoredSection() -> SettingsSection {
        let rawValue = UserDefaults.standard.string(forKey: selectedSectionDefaultsKey) ?? SettingsSection.general.rawValue
        return SettingsSection(rawValue: rawValue) ?? .general
    }

    private func persistSelectedSection() {
        UserDefaults.standard.set(selectedSection.rawValue, forKey: Self.selectedSectionDefaultsKey)
    }
}

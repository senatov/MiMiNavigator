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
    @State private var searchText = ""
    private static let selectedSectionDefaultsKey = "SettingsWindowView.selectedSection"

    private var filteredSections: [SettingsSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter {
            $0.label.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
                || $0.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

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
        .onChange(of: searchText) { _, _ in
            guard !filteredSections.isEmpty, !filteredSections.contains(selectedSection) else { return }
            selectedSection = filteredSections[0]
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Preferences")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 5)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search settings", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.65)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 5)

            // Section list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredSections) { section in
                        // Group header divider (e.g. "Colors", "Layout")
                        if let header = section.groupHeader {
                            groupLabel(header)
                        }
                        sidebarRow(section)
                    }
                    if filteredSections.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.tertiary)
                            Text("No matching settings")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
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
        HStack(spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.7)
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
            Image(systemName: selectedSection.icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SettingsVisualStyle.accent)
                .frame(width: 30, height: 30)
                .background(SettingsVisualStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        .padding(.top, 14)
        .padding(.bottom, 11)
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

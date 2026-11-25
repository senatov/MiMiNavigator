// SettingsTabsPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Tabs Settings
struct SettingsTabsPane: View {
    @State private var prefs = UserPreferences.shared
    @AppStorage("tabs.appearance.typeface") private var typeface = TabTypeface.system
    @AppStorage("tabs.appearance.separatorColor") private var separatorColor = TabAppearance.separatorColor
    @AppStorage("tabs.appearance.separatorWidth") private var separatorWidth = TabAppearance.separatorWidth
    @AppStorage("tabs.appearance.separatorShadow") private var separatorShadow = TabAppearance.separatorShadow
    @AppStorage("tabs.appearance.fontSize") private var fontSize = TabAppearance.fontSize
    @AppStorage("tabs.appearance.bottomRadius") private var bottomRadius = TabAppearance.bottomRadius
    @AppStorage("tabs.appearance.inactivePanelOpacity") private var inactivePanelOpacity = TabAppearance.inactivePanelOpacity
    @AppStorage("tabs.appearance.focusedBackground") private var focusedBackground = TabAppearance.focusedBackground
    @AppStorage("tabs.appearance.unfocusedBackground") private var unfocusedBackground = TabAppearance.unfocusedBackground
    @AppStorage("tabs.appearance.focusedText") private var focusedText = TabAppearance.focusedText
    @AppStorage("tabs.appearance.unfocusedText") private var unfocusedText = TabAppearance.unfocusedText

    // MARK: - Preference Binding
    private func prefBinding<T>(_ keyPath: WritableKeyPath<PreferencesSnapshot, T>) -> Binding<T> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] },
            set: {
                prefs.snapshot[keyPath: keyPath] = $0
                AppStateProvider.shared?.applyPreferencesFromSnapshot()
            }
        )
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Restore tabs:", help: "Reopen tabs from the last session on launch") {
                        Toggle("Restore tabs on launch", isOn: prefBinding(\.tabsRestoreOnLaunch)).toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Close button:", help: "Show the close button on active or hovered tabs") {
                        Toggle("Show close button on tabs", isOn: prefBinding(\.tabsShowCloseButton)).toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Max open tabs:", help: "Maximum number of tabs per panel") {
                        HStack(spacing: 10) {
                            Slider(value: prefBinding(\.tabsMaxTabs), in: 2...64, step: 1).frame(width: 140)
                            Text("\(Int(prefs.snapshot.tabsMaxTabs))").monospacedDigit().frame(width: 28)
                        }
                    }
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Tab typeface:", help: "Choose a system typeface for file panel tabs") {
                        Picker("Tab typeface", selection: $typeface) {
                            ForEach(TabTypeface.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    Divider()
                    sliderRow("Tab font size:", value: $fontSize, range: 11...18, format: "%.0f pt")
                    Divider()
                    sliderRow("Bottom corner radius:", value: $bottomRadius, range: 4...12, format: "%.0f pt")
                    Divider()
                    sliderRow("Inactive panel fill:", value: $inactivePanelOpacity, range: 0.2...1, format: "%.0f%%", multiplier: 100)
                    Divider()
                    colorRow("Active panel background:", hex: $focusedBackground, fallback: TabAppearance.focusedBackground)
                    Divider()
                    colorRow("Inactive panel background:", hex: $unfocusedBackground, fallback: TabAppearance.unfocusedBackground)
                    Divider()
                    colorRow("Active panel text:", hex: $focusedText, fallback: TabAppearance.focusedText)
                    Divider()
                    colorRow("Inactive panel text:", hex: $unfocusedText, fallback: TabAppearance.unfocusedText)
                }
            }
            SettingsGroupBox {
                VStack(spacing: 0) {
                    colorRow("Separator color:", hex: $separatorColor, fallback: TabAppearance.separatorColor)
                    Divider()
                    sliderRow("Separator thickness:", value: $separatorWidth, range: 0.25...2, format: "%.2f pt", step: 0.25)
                    Divider()
                    sliderRow("Separator shadow:", value: $separatorShadow, range: 0...0.5, format: "%.0f%%", multiplier: 100)
                }
            }
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        TabAppearancePreview(title: "Active panel", focused: true)
                        TabAppearancePreview(title: "Inactive panel", focused: false)
                    }
                }
            }
            HStack {
                Spacer()
                DownToolbarButtonView(title: "Reset tab appearance", systemImage: "arrow.counterclockwise", iconTint: .blue) { resetAppearance() }
            }
        }
    }

    // MARK: - Appearance Controls
    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, multiplier: Double = 1, step: Double? = nil) -> some View {
        SettingsRow(label: title, help: title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step ?? (multiplier == 100 ? 0.05 : 1)).frame(width: 140)
                Text(String(format: format, value.wrappedValue * multiplier))
                    .monospacedDigit().foregroundStyle(SettingsVisualStyle.secondaryText)
            }
        }
    }

    private func colorRow(_ title: String, hex: Binding<String>, fallback: String) -> some View {
        SettingsRow(label: title, help: title) {
            HStack(spacing: 8) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: hex.wrappedValue) ?? Color(hex: fallback) ?? .primary },
                    set: { hex.wrappedValue = $0.toHex() ?? fallback }
                )).labelsHidden().frame(width: 30)
                Text(hex.wrappedValue.uppercased()).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
            }
        }
    }

    // MARK: - Reset
    private func resetAppearance() {
        typeface = .system
        separatorColor = TabAppearance.separatorColor
        separatorWidth = TabAppearance.separatorWidth
        separatorShadow = TabAppearance.separatorShadow
        fontSize = TabAppearance.fontSize
        bottomRadius = TabAppearance.bottomRadius
        inactivePanelOpacity = TabAppearance.inactivePanelOpacity
        focusedBackground = TabAppearance.focusedBackground
        unfocusedBackground = TabAppearance.unfocusedBackground
        focusedText = TabAppearance.focusedText
        unfocusedText = TabAppearance.unfocusedText
    }
}

// MARK: - Tab Appearance Preview
private struct TabAppearancePreview: View {
    let title: String
    let focused: Bool

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                tab("Documents", selected: true)
                TabSeparator()
                tab("Downloads", selected: false)
            }
        }
    }

    // MARK: - Preview Tab
    private func tab(_ title: String, selected: Bool) -> some View {
        TabAppearanceLabel(title: title, systemIcon: "folder", compact: true, isSelected: selected, isFocused: focused)
            .padding(.horizontal, 7)
            .frame(height: TabAppearance.compactTabHeight)
            .background {
                PanelTabSurface(isActive: selected, isPanelFocused: focused, compact: true)
            }
    }
}

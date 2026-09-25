// SettingsTabsPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Tabs Settings
struct SettingsTabsPane: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var prefs = UserPreferences.shared
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        previewTab(focused: true)
                        previewTab(focused: false)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Reset tab appearance") { resetAppearance() }.buttonStyle(ThemedButtonStyle())
            }
        }
    }

    // MARK: - Appearance Controls
    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, multiplier: Double = 1) -> some View {
        SettingsRow(label: title, help: title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: multiplier == 100 ? 0.05 : 1).frame(width: 140)
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

    // MARK: - Preview
    private func previewTab(focused: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill").font(.system(size: 11))
            Text(focused ? "Active panel" : "Inactive panel")
                .font(.system(size: CGFloat(fontSize), weight: .regular))
        }
        .foregroundStyle(Color(hex: previewHex(focused ? focusedText : unfocusedText,
                                               dark: focused ? TabAppearance.darkFocusedText : TabAppearance.darkUnfocusedText,
                                               standard: focused ? TabAppearance.focusedText : TabAppearance.unfocusedText)) ?? .primary)
        .padding(.horizontal, 12)
        .frame(height: 29)
        .background {
            (Color(hex: previewHex(focused ? focusedBackground : unfocusedBackground,
                                   dark: focused ? TabAppearance.darkFocusedBackground : TabAppearance.darkUnfocusedBackground,
                                   standard: focused ? TabAppearance.focusedBackground : TabAppearance.unfocusedBackground)) ?? .gray)
                .opacity(focused ? 1 : inactivePanelOpacity)
                .clipShape(BottomSheetTabShape(bottomRadius: CGFloat(bottomRadius)))
        }
        .overlay(BottomSheetTabShape(bottomRadius: CGFloat(bottomRadius)).stroke(Color.accentColor.opacity(0.5), lineWidth: 0.7))
    }

    private func previewHex(_ hex: String, dark: String, standard: String) -> String {
        colorScheme == .dark && hex == standard ? dark : hex
    }

    // MARK: - Reset
    private func resetAppearance() {
        fontSize = TabAppearance.fontSize
        bottomRadius = TabAppearance.bottomRadius
        inactivePanelOpacity = TabAppearance.inactivePanelOpacity
        focusedBackground = TabAppearance.focusedBackground
        unfocusedBackground = TabAppearance.unfocusedBackground
        focusedText = TabAppearance.focusedText
        unfocusedText = TabAppearance.unfocusedText
    }
}

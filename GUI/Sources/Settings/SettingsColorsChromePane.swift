// SettingsColorsChromePane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors › "Chrome & Borders" — panel borders, dividers,
//   zebra stripes, warm white, filter bar highlight.

import SwiftUI

// MARK: - SettingsColorsChromePane
struct SettingsColorsChromePane: View, ColorPaneHelpers {

    @State private var store = ColorThemeStore.shared

    @AppStorage("color.dividerNormal")       private var hexDividerNormal: String = ""
    @AppStorage("color.dividerActive")       private var hexDividerActive: String = ""
    @AppStorage("color.panelBorderActive")   private var hexBorderActive: String = ""
    @AppStorage("color.panelBorderInactive") private var hexBorderInactive: String = ""
    @AppStorage("panel.borderWidth")         private var panelBorderWidth: Double = 0
    @AppStorage("color.warmWhite")           private var hexWarmWhite: String = ""
    @AppStorage("color.zebraActiveEven")     private var hexZebraActiveEven: String = ""
    @AppStorage("color.zebraActiveOdd")      private var hexZebraActiveOdd: String = ""
    @AppStorage("color.zebraInactiveEven")   private var hexZebraInactiveEven: String = ""
    @AppStorage("color.zebraInactiveOdd")    private var hexZebraInactiveOdd: String = ""
    @AppStorage("color.filterActive")        private var hexFilterActive: String = ""
    @AppStorage("color.commandBarBackground")
    private var hexCommandBarBackground = CommandBarAppearanceDefaults.backgroundHex
    @AppStorage("commandBar.moireIntensity")
    private var commandBarMoireIntensity = CommandBarAppearanceDefaults.moireIntensity

    private var preset: ColorTheme { ColorThemeStore.shared.activeTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Command Bars ───────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Command Bars")
                    commandBarColorRow
                    Divider()
                    sliderRow("Moire", help: "Shared texture intensity for the top and bottom command bars",
                              value: $commandBarMoireIntensity, range: 0...1, step: 0.05,
                              displayFormat: "%.2f") {}
                }
            }

            // ── Panel Divider ──────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Panel Divider")
                    colorRow("Normal", help: "Divider color — passive state",
                             preset: preset.dividerNormalColor, hex: $hexDividerNormal, store: store)
                    Divider()
                    colorRow("Active", help: "Divider color while dragging",
                             preset: preset.dividerActiveColor, hex: $hexDividerActive, store: store)
                }
            }

            // ── Panel Border ───────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Panel Border")
                    colorRow("Focused panel",   help: "Border — active (focused) panel",
                             preset: preset.panelBorderActive,   hex: $hexBorderActive,   store: store)
                    Divider()
                    colorRow("Unfocused panel", help: "Border — inactive panel",
                             preset: preset.panelBorderInactive, hex: $hexBorderInactive, store: store)
                    Divider()
                    sliderRow("Width", help: "Panel border thickness (default 1.5)",
                              value: $panelBorderWidth, range: 0.25...4.0, step: 0.25,
                              displayFormat: "%.2f", unit: " pt") {
                        store.storedPanelBorderWidth = panelBorderWidth
                        store.reloadOverrides()
                    }
                }
            }

            // ── Table Background ───────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Table Background")
                    colorRow("Warm white", help: "Active panel header / table background tint",
                             preset: preset.warmWhite, hex: $hexWarmWhite, store: store)
                    Divider()
                    sectionHeader("Zebra Stripes — Active Panel")
                    colorRow("Even rows", help: "Active panel — even row bg",
                             preset: preset.zebraActiveEven, hex: $hexZebraActiveEven, store: store)
                    Divider()
                    colorRow("Odd rows",  help: "Active panel — odd row bg",
                             preset: preset.zebraActiveOdd,  hex: $hexZebraActiveOdd,  store: store)
                    Divider()
                    sectionHeader("Zebra Stripes — Inactive Panel")
                    colorRow("Even rows", help: "Inactive panel — even row bg",
                             preset: preset.zebraInactiveEven, hex: $hexZebraInactiveEven, store: store)
                    Divider()
                    colorRow("Odd rows",  help: "Inactive panel — odd row bg",
                             preset: preset.zebraInactiveOdd,  hex: $hexZebraInactiveOdd,  store: store)
                }
            }

            // ── Filter Bar ─────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Filter Bar")
                    colorRow("Active highlight", help: "Filter bar border glow when focused",
                             preset: preset.filterActiveColor, hex: $hexFilterActive, store: store)
                }
            }

            resetButton {
                hexDividerNormal = ""; hexDividerActive = ""
                hexBorderActive  = ""; hexBorderInactive = ""; panelBorderWidth = 0
                hexWarmWhite = ""
                hexZebraActiveEven   = ""; hexZebraActiveOdd = ""
                hexZebraInactiveEven = ""; hexZebraInactiveOdd = ""
                hexFilterActive = ""
                hexCommandBarBackground = CommandBarAppearanceDefaults.backgroundHex
                commandBarMoireIntensity = CommandBarAppearanceDefaults.moireIntensity
                store.storedPanelBorderWidth = 0
                store.reloadOverrides()
            }
        }
    }

    private var commandBarColorRow: some View {
        rowLabel("Background:", help: "Shared background color for the top menu and bottom action bar") {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(CommandBarAppearanceDefaults.backgroundColor)
                    .frame(width: 22, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                    .help("Default")
                Text("→")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                ColorPicker("", selection: commandBarColorBinding)
                    .labelsHidden()
                    .frame(width: 28)
                if hexCommandBarBackground != CommandBarAppearanceDefaults.backgroundHex {
                    Button {
                        hexCommandBarBackground = CommandBarAppearanceDefaults.backgroundHex
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reset to default")
                }
            }
        }
    }

    private var commandBarColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: hexCommandBarBackground)
                    ?? CommandBarAppearanceDefaults.backgroundColor
            },
            set: { newColor in
                hexCommandBarBackground = newColor.toHex() ?? ""
            }
        )
    }
}

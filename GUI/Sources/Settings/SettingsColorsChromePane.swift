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

    private var preset: ColorTheme { ColorThemeStore.shared.activeTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

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
                store.storedPanelBorderWidth = 0
                store.reloadOverrides()
            }
        }
    }
}

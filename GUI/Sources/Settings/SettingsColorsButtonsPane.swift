// SettingsColorsButtonsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors › "Buttons" — border color/width, corner radius,
//   shadow color/radius/offset, live preview.

import SwiftUI

// MARK: - SettingsColorsButtonsPane
struct SettingsColorsButtonsPane: View, ColorPaneHelpers {

    @State private var store = ColorThemeStore.shared

    @AppStorage("button.borderColor") private var hexButtonBorder: String = ""
    @AppStorage("button.shadowColor") private var hexButtonShadow: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Border ─────────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Border")
                    colorRow("Color", help: "Button border color",
                             preset: Color.gray.opacity(0.35), hex: $hexButtonBorder, store: store)
                    Divider()
                    sliderRow("Width",  help: "Button border line thickness",
                              value: $store.buttonBorderWidth, range: 0...3, step: 0.25,
                              displayFormat: "%.2f", unit: " pt") {}
                    Divider()
                    sliderRow("Corner radius", help: "Roundness of button corners",
                              value: $store.buttonCornerRadius, range: 0...16, step: 1,
                              displayFormat: "%.0f", unit: " pt") {}
                }
            }

            // ── Shadow ─────────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Shadow")
                    colorRow("Color", help: "Shadow color under buttons",
                             preset: Color.black.opacity(0.1), hex: $hexButtonShadow, store: store)
                    Divider()
                    sliderRow("Radius",   help: "Shadow blur radius",
                              value: $store.buttonShadowRadius, range: 0...8, step: 0.5,
                              displayFormat: "%.1f", unit: " pt") {}
                    Divider()
                    sliderRow("Y offset", help: "Vertical shadow offset",
                              value: $store.buttonShadowY, range: 0...4, step: 0.5,
                              displayFormat: "%.1f", unit: " pt") {}
                }
            }

            // ── Live Preview ───────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Preview")
                    rowLabel("Buttons:", help: "How styled buttons look with current settings") {
                        HStack(spacing: 12) {
                            Button("OK")     {}.buttonStyle(ThemedButtonStyle())
                            Button("Cancel") {}.buttonStyle(ThemedButtonStyle())
                            Button("Reset")  {}.buttonStyle(ThemedButtonStyle()).tint(.red)
                        }
                    }
                }
            }

            resetButton {
                hexButtonBorder = ""; hexButtonShadow = ""
                store.buttonBorderWidth  = 0.5
                store.buttonCornerRadius = 6.0
                store.buttonShadowRadius = 1.0
                store.buttonShadowY      = 0.5
            }
        }
    }
}

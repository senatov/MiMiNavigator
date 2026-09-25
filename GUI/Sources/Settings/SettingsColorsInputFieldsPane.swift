// SettingsColorsInputFieldsPane.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings for dialog input placeholders and field labels.

import SwiftUI

// MARK: - Settings Colors Input Fields Pane
struct SettingsColorsInputFieldsPane: View, ColorPaneHelpers {
    @AppStorage(DialogTextInputAppearance.placeholderColorKey)
    private var placeholderHex = DialogTextInputAppearance.defaultPlaceholderHex
    @AppStorage(DialogTextInputAppearance.placeholderOpacityKey)
    private var placeholderOpacity = DialogTextInputAppearance.defaultPlaceholderOpacity
    @AppStorage(DialogTextInputAppearance.labelColorKey)
    private var labelHex = DialogTextInputAppearance.defaultLabelHex
    @State private var previewText = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Dialog Input Fields")
                    colorRow(
                        "Placeholder",
                        help: "Color of input hints shown before text is entered",
                        preset: Color(hex: DialogTextInputAppearance.defaultPlaceholderHex) ?? .secondary,
                        hex: $placeholderHex,
                        store: ColorThemeStore.shared
                    )
                    Divider()
                    opacityRow
                    Divider()
                    colorRow(
                        "Field label",
                        help: "Color of labels beside dialog input fields",
                        preset: Color(hex: DialogTextInputAppearance.defaultLabelHex) ?? .blue,
                        hex: $labelHex,
                        store: ColorThemeStore.shared
                    )
                }
            }
            paneGroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Preview")
                    SettingsRow(label: "Host:", help: "Input appearance preview", labelWidth: 90) {
                        DialogTextField("host or user@host:port or ftp://host/path", text: $previewText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            resetButton {
                placeholderHex = DialogTextInputAppearance.defaultPlaceholderHex
                placeholderOpacity = DialogTextInputAppearance.defaultPlaceholderOpacity
                labelHex = DialogTextInputAppearance.defaultLabelHex
            }
        }
    }
    private var opacityRow: some View {
        rowLabel("Hint intensity:", help: "Lower values make placeholders clearly look like hints") {
            HStack(spacing: 10) {
                Slider(value: $placeholderOpacity, in: 0.20 ... 0.70, step: 0.05)
                    .frame(width: 150)
                Text("\(Int(placeholderOpacity * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}

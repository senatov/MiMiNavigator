// SettingsProgressPane.swift
// MiMiNavigator
//
// Created by Claude on 19.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings pane for ProgressPanel appearance — colors, font, size preview.

import SwiftUI

// MARK: - Settings Progress Pane

struct SettingsProgressPane: View {

    @State private var appearance = ProgressPanelAppearance.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: - Background & Border
            GroupBox("Background") {
                VStack(alignment: .leading, spacing: 10) {
                    colorRow(label: "Panel background", hex: $appearance.hexBackground)
                    colorRow(label: "Border", hex: $appearance.hexBorder)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Text Colors
            GroupBox("Text Colors") {
                VStack(alignment: .leading, spacing: 10) {
                    colorRow(label: "Title", hex: $appearance.hexTitleColor)
                    colorRow(label: "Status line", hex: $appearance.hexStatusColor)
                    colorRow(label: "Log text", hex: $appearance.hexLogColor)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Log Font
            GroupBox("Log Font") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Font:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Font name", text: $appearance.logFontName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                        Text("Size:")
                        TextField("", value: $appearance.logFontSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("pt")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))

                    // font preview
                    Text("1. ~/Downloads/Musor/Привет Мир.fb2")
                        .font(Font(appearance.logFont))
                        .foregroundColor(Color(nsColor: appearance.logColor))
                        .padding(6)
                        .background(Color(nsColor: appearance.bgColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: appearance.borderColor), lineWidth: 0.5)
                        )
                }
                .padding(.vertical, 4)
            }

            // MARK: - Panel Size
            GroupBox("Panel Size") {
                HStack(spacing: 16) {
                    HStack {
                        Text("Width:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("", value: Binding(
                            get: { Double(appearance.panelWidth) },
                            set: { appearance.panelWidth = CGFloat($0) }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Height:")
                        TextField("", value: Binding(
                            get: { Double(appearance.panelHeight) },
                            set: { appearance.panelHeight = CGFloat($0) }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    Text("px")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .padding(.vertical, 4)
            }

            // MARK: - Actions
            HStack {
                Button("Reset to Defaults") {
                    appearance.resetToDefaults()
                }
                Spacer()
                Button("Save") {
                    appearance.save()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }

    // MARK: - Color Row Helper

    private func colorRow(label: String, hex: Binding<String>) -> some View {
        HStack {
            Text(label + ":")
                .frame(width: 120, alignment: .trailing)
                .font(.system(size: 12))
            ColorPicker("", selection: hexBinding(hex), supportsOpacity: false)
                .labelsHidden()
            TextField("", text: hex)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    /// Bridge hex string ↔ SwiftUI Color for ColorPicker
    private func hexBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                let resolved: Color = Color(hex: hex.wrappedValue) ?? .gray
                return resolved
            },
            set: { (newColor: Color) in
                hex.wrappedValue = newColor.toHex() ?? hex.wrappedValue
            }
        )
    }
}

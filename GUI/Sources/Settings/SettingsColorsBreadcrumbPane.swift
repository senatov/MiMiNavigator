// SettingsColorsBreadcrumbPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors › "BreadCrumb" — text color active/inactive,
//   background active/inactive, font size, dual live preview.

import SwiftUI

// MARK: - SettingsColorsBreadcrumbPane
struct SettingsColorsBreadcrumbPane: View, ColorPaneHelpers {

    @State private var store = ColorThemeStore.shared

    @AppStorage("color.breadcrumbTextActive")   private var hexTextActive:   String = ""
    @AppStorage("color.breadcrumbTextInactive") private var hexTextInactive: String = ""
    @AppStorage("color.breadcrumbBgActive")     private var hexBgActive:     String = ""
    @AppStorage("color.breadcrumbBgInactive")   private var hexBgInactive:   String = ""
    @AppStorage("breadcrumb.fontSize")          private var storedFontSize:  Double = 0

    private var preset: ColorTheme { ColorThemeStore.shared.activeTheme }

    private var previewFontSize: CGFloat {
        storedFontSize > 0 ? CGFloat(storedFontSize) : preset.breadcrumbFontSize
    }

    var body: some View {
        let _ = log.debug("[BreadcrumbPane] body: textAct='\(hexTextActive)' textInact='\(hexTextInactive)' bgAct='\(hexBgActive)' bgInact='\(hexBgInactive)' UD.bgAct='\(UserDefaults.standard.string(forKey: "color.breadcrumbBgActive") ?? "nil")' UD.bgInact='\(UserDefaults.standard.string(forKey: "color.breadcrumbBgInactive") ?? "nil")'")
        VStack(alignment: .leading, spacing: 16) {

            // ── Colors ─────────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Text")
                    colorRow("Active panel",   help: "Path text color — focused panel",
                             preset: preset.breadcrumbTextActive,   hex: $hexTextActive,   store: store)
                    Divider()
                    colorRow("Inactive panel", help: "Path text color — unfocused panel",
                             preset: preset.breadcrumbTextInactive, hex: $hexTextInactive, store: store)
                    Divider()
                    sectionHeader("Background")
                    colorRow("Active panel",   help: "BreadCrumb bar background — focused",
                             preset: preset.breadcrumbBgActive,     hex: $hexBgActive,     store: store)
                    Divider()
                    colorRow("Inactive panel", help: "BreadCrumb bar background — unfocused",
                             preset: preset.breadcrumbBgInactive,   hex: $hexBgInactive,   store: store)
                }
            }

            // ── Typography ─────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Typography")
                    sliderRow("Font size", help: "Path text size in points (default 11.5 pt)",
                              value: $storedFontSize, range: 9...16, step: 0.5,
                              displayFormat: "%.1f", unit: " pt") {
                        store.breadcrumbFontSize = storedFontSize
                        store.reloadOverrides()
                    }
                }
            }

            // ── Live Preview ───────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Preview")
                    rowLabel("Active:", help: "Focused panel breadcrumb") {
                        crumbPreview(
                            text: Color(hex: hexTextActive)   ?? preset.breadcrumbTextActive,
                            bg:   Color(hex: hexBgActive)     ?? preset.breadcrumbBgActive,
                            alpha: 0.55
                        )
                    }
                    Divider()
                    rowLabel("Inactive:", help: "Unfocused panel breadcrumb") {
                        crumbPreview(
                            text: Color(hex: hexTextInactive) ?? preset.breadcrumbTextInactive,
                            bg:   Color(hex: hexBgInactive)   ?? preset.breadcrumbBgInactive,
                            alpha: 0.30
                        )
                    }
                }
            }

            resetButton {
                hexTextActive = ""; hexTextInactive = ""
                hexBgActive   = ""; hexBgInactive   = ""
                storedFontSize = 0
                store.breadcrumbFontSize = 0
                store.reloadOverrides()
            }
        }
    }

    // MARK: - crumbPreview helper
    private func crumbPreview(text: Color, bg: Color, alpha: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(["Applications", "Utilities", "Terminal"], id: \.self) { seg in
                if seg != "Applications" {
                    Image(systemName: "arrowtriangle.forward")
                        .font(.system(size: 8))
                        .foregroundStyle(text.opacity(0.5))
                }
                Text(seg)
                    .font(.system(size: previewFontSize, weight: .regular, design: .rounded))
                    .foregroundStyle(text)
                    .kerning(0.1)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(bg))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.32, alpha: alpha)),
                        lineWidth: 0.75)
        )
    }
}

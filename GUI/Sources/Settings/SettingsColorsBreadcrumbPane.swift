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
    @AppStorage("color.breadcrumbVariable")     private var hexVariable:     String = ""
    @AppStorage("color.breadcrumbHoverText") private var hexHoverText: String = ""
    @AppStorage("color.breadcrumbHoverBackground") private var hexHoverBackground: String = ""
    @AppStorage("color.breadcrumbHoverBorder") private var hexHoverBorder: String = ""
    @AppStorage("breadcrumb.fontSize")          private var storedFontSize:  Double = 0
    @AppStorage("breadcrumb.hoverFontSize") private var storedHoverFontSize: Double = 0
    @AppStorage("breadcrumb.variableItalic")    private var variableItalic:  Bool = true

    private var preset: ColorTheme { ColorThemeStore.shared.activeTheme }

    private var previewFontSize: CGFloat {
        storedFontSize > 0 ? CGFloat(storedFontSize) : preset.breadcrumbFontSize
    }

    var body: some View {
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
                    colorRow("Environment variable", help: "Text color for $VAR path segments",
                             preset: preset.breadcrumbVariableColor, hex: $hexVariable, store: store)
                    Divider()
                    colorRow("Hovered segment", help: "Text color for the path segment under the pointer",
                             preset: ColorThemeStore.defaultBreadcrumbHoverText, hex: $hexHoverText, store: store)
                    Divider()
                    sectionHeader("Background")
                    colorRow("Active panel",   help: "BreadCrumb bar background — focused",
                             preset: preset.breadcrumbBgActive,     hex: $hexBgActive,     store: store)
                    Divider()
                    colorRow("Inactive panel", help: "BreadCrumb bar background — unfocused",
                             preset: preset.breadcrumbBgInactive,   hex: $hexBgInactive,   store: store)
                    Divider()
                    colorRow("Hovered segment", help: "Background color for the path segment under the pointer",
                             preset: ColorThemeStore.defaultBreadcrumbHoverBackground, hex: $hexHoverBackground, store: store)
                    Divider()
                    colorRow("Hover border", help: "Border color for the path segment under the pointer",
                             preset: ColorThemeStore.defaultBreadcrumbHoverBorder, hex: $hexHoverBorder, store: store)
                }
            }

            // ── Typography ─────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Typography")
                    sliderRow("Font size", help: "Path text size in points (default 14 pt)",
                              value: $storedFontSize, range: 9...16, step: 0.5,
                              displayFormat: "%.1f", unit: " pt") {
                        store.breadcrumbFontSize = storedFontSize
                        store.reloadOverrides()
                    }
                    Divider()
                    sliderRow("Hover font size", help: "Text size for the path segment under the pointer",
                              value: hoverFontSizeBinding, range: 9...20, step: 0.5,
                              displayFormat: "%.1f", unit: " pt") {
                        store.breadcrumbHoverFontSize = storedHoverFontSize
                        store.reloadOverrides()
                    }
                    Divider()
                    Toggle("Italic environment variables", isOn: $variableItalic)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
                            alpha: 0.55,
                            isActive: true
                        )
                    }
                    Divider()
                    rowLabel("Inactive:", help: "Unfocused panel breadcrumb") {
                        crumbPreview(
                            text: Color(hex: hexTextInactive) ?? preset.breadcrumbTextInactive,
                            bg:   Color(hex: hexBgInactive)   ?? preset.breadcrumbBgInactive,
                            alpha: 0.30,
                            isActive: false
                        )
                    }
                }
            }

            resetButton {
                hexTextActive = ""; hexTextInactive = ""
                hexVariable = ""
                hexHoverText = ""; hexHoverBackground = ""; hexHoverBorder = ""
                hexBgActive   = ""; hexBgInactive   = ""
                storedFontSize = 0
                storedHoverFontSize = 0
                variableItalic = true
                store.breadcrumbFontSize = 0
                store.breadcrumbHoverFontSize = 0
                store.reloadOverrides()
            }
        }
    }

    // MARK: - crumbPreview helper
    private func crumbPreview(text: Color, bg: Color, alpha: Double, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            previewNavigationIcons(isActive: isActive)
            ForEach(Array(previewSegments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    BreadCrumbSeparator(fontSize: previewFontSize)
                }
                ExpandableSegmentButton(
                    segment: segment,
                    textColor: text,
                    variableTextColor: Color(hex: hexVariable) ?? preset.breadcrumbVariableColor,
                    variableItalic: variableItalic,
                    fontSize: previewFontSize,
                    hoverTextColor: Color(hex: hexHoverText) ?? ColorThemeStore.defaultBreadcrumbHoverText,
                    hoverBackgroundColor: Color(hex: hexHoverBackground) ?? ColorThemeStore.defaultBreadcrumbHoverBackground,
                    hoverBorderColor: Color(hex: hexHoverBorder) ?? ColorThemeStore.defaultBreadcrumbHoverBorder,
                    hoverFontSize: previewHoverFontSize,
                    onTap: {},
                    helpText: segment.fullName,
                    copyAction: {}
                )
            }
            Spacer(minLength: 4)
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(text)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 1)
        .frame(maxWidth: 520, minHeight: 34, maxHeight: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(bg))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.32, alpha: alpha)),
                        lineWidth: 0.75)
        )
    }

    private var previewHoverFontSize: CGFloat {
        storedHoverFontSize > 0 ? CGFloat(storedHoverFontSize) : previewFontSize * 1.13
    }

    private var hoverFontSizeBinding: Binding<Double> {
        Binding(
            get: { storedHoverFontSize > 0 ? storedHoverFontSize : Double(previewFontSize * 1.13) },
            set: { storedHoverFontSize = $0 }
        )
    }

    private var previewSegments: [BreadCrumbView.DisplaySegment] {
        ["$HOME", "Library", "Mobile Documents"].enumerated().map { index, name in
            BreadCrumbView.DisplaySegment(
                text: name,
                fullName: name,
                originalIndex: index,
                isEnvironmentVariable: name.hasPrefix("$"),
                showsSeparatorBefore: index > 0,
                isCollapsedChain: false
            )
        }
    }

    private func previewNavigationIcons(isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.backward")
            Image(systemName: "arrowshape.up")
            Image(systemName: "arrowshape.turn.up.forward")
                .opacity(0.35)
        }
        .font(.system(size: 15, weight: .light))
        .foregroundStyle(Color(nsColor: .labelColor).opacity(isActive ? 1 : 0.45))
        .frame(height: 28)
        .padding(.leading, 5)
    }
}

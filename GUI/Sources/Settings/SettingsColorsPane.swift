// SettingsColorsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors settings pane View only.
//   ColorTheme model → Config/ColorTheme.swift
//   Color+Hex helpers → Views/Color+Hex.swift — named color tokens, Light/Dark variants, preset themes.
//   All colors pulled from FilePanelStyle, DesignTokens, DialogColors.
//   Stored in AppStorage as hex strings, applied via ColorThemeStore.

import AppKit
import SwiftUI



// MARK: - SettingsColorsPane

struct SettingsColorsPane: View {

    @State private var store = ColorThemeStore.shared
    @State private var selectedPresetID: String = ColorThemeStore.shared.activeTheme.id
    @State private var useDarkVariant: Bool = ColorThemeStore.shared.useDarkVariant

    // Custom color bindings (shown in color wells)
    @AppStorage("color.panelBackground")   private var hexPanelBg: String = ""
    @AppStorage("color.panelText")         private var hexPanelText: String = ""
    @AppStorage("color.dirName")           private var hexDirName: String = ""
    @AppStorage("color.fileName")          private var hexFileName: String = ""
    @AppStorage("color.symlink")           private var hexSymlink: String = ""
    @AppStorage("color.selectionActive")   private var hexSelActive: String = ""
    @AppStorage("color.selectionInactive") private var hexSelInactive: String = ""
    @AppStorage("color.selectionBorder")   private var hexSelBorder: String = ""
    @AppStorage("selection.lineWidth")     private var selLineWidth: Double = 2.0
    @AppStorage("color.accent")            private var hexAccent: String = ""
    @AppStorage("color.dialogBackground")  private var hexDialogBg: String = ""
    @AppStorage("button.borderColor")        private var hexButtonBorder: String = ""
    @AppStorage("button.shadowColor")        private var hexButtonShadow: String = ""
    // Extended color tokens
    @AppStorage("color.hiddenFile")       private var hexHiddenFile: String = ""
    @AppStorage("color.markedFile")       private var hexMarkedFile: String = ""
    @AppStorage("color.parentEntry")      private var hexParentEntry: String = ""
    @AppStorage("color.archivePath")      private var hexArchivePath: String = ""
    @AppStorage("color.markedCount")      private var hexMarkedCount: String = ""
    @AppStorage("color.columnName")       private var hexColumnName: String = ""
    @AppStorage("color.columnSize")       private var hexColumnSize: String = ""
    @AppStorage("color.columnKind")       private var hexColumnKind: String = ""
    @AppStorage("color.columnDate")       private var hexColumnDate: String = ""
    @AppStorage("color.columnPermissions") private var hexColumnPermissions: String = ""
    @AppStorage("color.columnOwner")       private var hexColumnOwner: String = ""
    @AppStorage("color.columnGroup")       private var hexColumnGroup: String = ""
    @AppStorage("color.columnChildCount")  private var hexColumnChildCount: String = ""
    @AppStorage("color.dividerNormal")    private var hexDividerNormal: String = ""
    @AppStorage("color.dividerActive")    private var hexDividerActive: String = ""
    @AppStorage("color.panelBorderActive")   private var hexPanelBorderActive: String = ""
    @AppStorage("color.panelBorderInactive") private var hexPanelBorderInactive: String = ""
    @AppStorage("color.warmWhite")        private var hexWarmWhite: String = ""
    @AppStorage("color.filterActive")     private var hexFilterActive: String = ""

    private var currentPreset: ColorTheme {
        ColorTheme.allPresets.first { $0.id == selectedPresetID } ?? .defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Theme Preset Picker ──────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    rowLabel("Theme preset:", help: "Choose a built-in color theme as starting point") {
                        HStack(spacing: 8) {
                            Picker("", selection: $selectedPresetID) {
                                ForEach(ColorTheme.allPresets) { theme in
                                    Text(theme.name).tag(theme.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                            .onChange(of: selectedPresetID) { _, id in
                                store.applyPreset(ColorTheme.allPresets.first { $0.id == id } ?? .defaultTheme)
                            }

                            // Live preview swatches
                            HStack(spacing: 4) {
                                swatch(currentPreset.panelBackground, label: "BG")
                                swatch(currentPreset.panelText, label: "Text")
                                swatch(currentPreset.dirNameColor, label: "Dir")
                                swatch(currentPreset.selectionActive, label: "Sel")
                                swatch(currentPreset.accentColor, label: "Acc")
                            }
                        }
                    }

                    Divider()

                    rowLabel("Dark variant:", help: "Use separate dark-mode colors when system is in Dark Mode") {
                        Toggle("Use separate dark-mode colors", isOn: $useDarkVariant)
                            .toggleStyle(.checkbox)
                            .onChange(of: useDarkVariant) { _, v in store.useDarkVariant = v }
                    }
                }
            }

            // ── Color Tokens ─────────────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Panel")
                    colorRow("Panel background",  help: "Background color of file list panels",
                             preset: currentPreset.panelBackground,    hex: $hexPanelBg)
                    Divider()
                    colorRow("File name",         help: "Regular file name text color",
                             preset: currentPreset.fileNameColor,      hex: $hexFileName)
                    Divider()
                    colorRow("Directory name",    help: "Directory name text color",
                             preset: currentPreset.dirNameColor,       hex: $hexDirName)
                    Divider()
                    colorRow("Symlink",           help: "Symbolic link name color",
                             preset: currentPreset.symlinkColor,       hex: $hexSymlink)
                }
            }

            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Selection")
                    colorRow("Active selection",   help: "Selected row when panel is focused",
                             preset: currentPreset.selectionActive,    hex: $hexSelActive)
                    Divider()
                    colorRow("Inactive selection", help: "Selected row when panel is unfocused",
                             preset: currentPreset.selectionInactive,  hex: $hexSelInactive)
                    Divider()
                    colorRow("Selection border",  help: "Top and bottom lines of selected row",
                             preset: currentPreset.selectionBorder,    hex: $hexSelBorder)
                    Divider()
                    HStack {
                        Text("Line width:")
                            .frame(width: 150, alignment: .trailing)
                        Slider(value: $selLineWidth,
                         in: 0.5...4.0, step: 0.5)
                        Text(String(format: "%.1f", selLineWidth))
                            .frame(width: 30)
                    }
                    .padding(.vertical, 4)
                }
            }

            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Accent")
                    colorRow("Accent color", help: "Used for buttons, highlights, active borders",
                             preset: currentPreset.accentColor, hex: $hexAccent)
                }
            }

            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Dialogs")
                    colorRow("Dialog background",
                             help: "Background of Find Files, Settings, and other floating panels. Matches active panel color at 92% opacity.",
                             preset: currentPreset.dialogBackground,
                             hex: $hexDialogBg)
                }
            }


            // ── File States ──────────────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("File States")
                    colorRow("Hidden files", help: "Dimmed text for .dotfiles",
                             preset: currentPreset.hiddenFileColor, hex: $hexHiddenFile)
                    Divider()
                    colorRow("Marked files", help: "TC-style marked file text (Insert key)",
                             preset: currentPreset.markedFileColor, hex: $hexMarkedFile)
                    Divider()
                    colorRow("Parent entry", help: "Color of '..' parent directory row",
                             preset: currentPreset.parentEntryColor, hex: $hexParentEntry)
                    Divider()
                    colorRow("Archive path", help: "Text color for files found inside archives",
                             preset: currentPreset.archivePathColor, hex: $hexArchivePath)
                    Divider()
                    colorRow("Marked count", help: "Status bar marked files counter",
                             preset: currentPreset.markedCountColor, hex: $hexMarkedCount)
                }
            }

            // ── Column Colors ────────────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Column Colors")
                    colorRow("Name column", help: "Text accent for Name column content",
                             preset: currentPreset.columnNameColor, hex: $hexColumnName)
                    Divider()
                    colorRow("Size column", help: "Text accent for Size column content",
                             preset: currentPreset.columnSizeColor, hex: $hexColumnSize)
                    Divider()
                    colorRow("Kind column", help: "Text accent for Kind column content",
                             preset: currentPreset.columnKindColor, hex: $hexColumnKind)
                    Divider()
                    colorRow("Date column", help: "Text accent for all Date columns",
                             preset: currentPreset.columnDateColor, hex: $hexColumnDate)
                    Divider()
                    colorRow("Permissions column", help: "Text accent for Permissions column",
                               preset: currentPreset.columnPermissionsColor, hex: $hexColumnPermissions)
                    Divider()
                    colorRow("Owner column", help: "Text accent for Owner column",
                               preset: currentPreset.columnOwnerColor, hex: $hexColumnOwner)
                    Divider()
                    colorRow("Group column", help: "Text accent for Group column",
                               preset: currentPreset.columnGroupColor, hex: $hexColumnGroup)
                    Divider()
                    colorRow("# Count column", help: "Text accent for child count column",
                               preset: currentPreset.columnChildCountColor, hex: $hexColumnChildCount)
                }
            }

            // ── UI Chrome ────────────────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("UI Chrome")
                    colorRow("Divider normal", help: "Panel divider color in passive state",
                             preset: currentPreset.dividerNormalColor, hex: $hexDividerNormal)
                    Divider()
                    colorRow("Divider active", help: "Panel divider color while dragging",
                             preset: currentPreset.dividerActiveColor, hex: $hexDividerActive)
                    Divider()
                    colorRow("Panel border (active)", help: "Focused panel border color",
                             preset: currentPreset.panelBorderActive, hex: $hexPanelBorderActive)
                    Divider()
                    colorRow("Panel border (inactive)", help: "Unfocused panel border color",
                             preset: currentPreset.panelBorderInactive, hex: $hexPanelBorderInactive)
                    Divider()
                    colorRow("Warm white", help: "Active panel zebra stripe background",
                             preset: currentPreset.warmWhite, hex: $hexWarmWhite)
                    Divider()
                    colorRow("Filter highlight", help: "Filter bar border when focused",
                             preset: currentPreset.filterActiveColor, hex: $hexFilterActive)
                }
            }

            // ── Buttons ───────────────────────────────────────────
            settingsGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Buttons")
                    colorRow("Border color", help: "Border color for themed buttons",
                             preset: Color.gray.opacity(0.35), hex: $hexButtonBorder)
                    Divider()
                    rowLabel("Border width:", help: "Thickness of button border line") {
                        HStack(spacing: 10) {
                            Slider(value: $store.buttonBorderWidth, in: 0...3, step: 0.25)
                                .frame(width: 120)
                            Text(String(format: "%.2f", store.buttonBorderWidth))
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    rowLabel("Corner radius:", help: "Roundness of button corners") {
                        HStack(spacing: 10) {
                            Slider(value: $store.buttonCornerRadius, in: 0...16, step: 1)
                                .frame(width: 120)
                            Text("\(Int(store.buttonCornerRadius)) pt")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    colorRow("Shadow color", help: "Shadow color under buttons",
                             preset: Color.black.opacity(0.1), hex: $hexButtonShadow)
                    Divider()
                    rowLabel("Shadow radius:", help: "Blur radius of button shadow") {
                        HStack(spacing: 10) {
                            Slider(value: $store.buttonShadowRadius, in: 0...8, step: 0.5)
                                .frame(width: 120)
                            Text(String(format: "%.1f", store.buttonShadowRadius))
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    // Live preview
                    rowLabel("Preview:", help: "How themed buttons look with current settings") {
                        HStack(spacing: 12) {
                            Button("Settings") {}
                                .buttonStyle(ThemedButtonStyle())
                            Button("Reset to Default") {}
                                .buttonStyle(ThemedButtonStyle())
                        }
                    }
                }
            }

            // ── Reset ─────────────────────────────────────────
            HStack {
                Spacer()
                Button("Reset to Default") {
                    selectedPresetID = "default"
                    store.applyPreset(.defaultTheme)
                    // Reset button params too
                    store.hexButtonBorder = ""
                    store.buttonBorderWidth = 0.5
                    store.buttonCornerRadius = 6.0
                    store.hexButtonShadow = ""
                    store.buttonShadowRadius = 1.0
                    store.buttonShadowY = 0.5
                }
                .buttonStyle(ThemedButtonStyle())
                .tint(.red)
            }
        }
    }

    // MARK: - Helpers

    private func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 18, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.1), lineWidth: 0.5))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 0)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }

    /// One color token row: label + preset swatch + override ColorPicker + reset button
    private func colorRow(_ label: String, help: String, preset: Color, hex: Binding<String>) -> some View {
        rowLabel(label + ":", help: help) {
            HStack(spacing: 10) {
                // Preset default swatch (read-only reference)
                RoundedRectangle(cornerRadius: 3)
                    .fill(preset)
                    .frame(width: 22, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                    .help("Preset default")

                Text("→")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))

                // Custom override ColorPicker
                ColorPicker("", selection: colorBinding(hex: hex, fallback: preset))
                    .labelsHidden()
                    .frame(width: 28)

                // Reset individual token
                if !hex.wrappedValue.isEmpty {
                    Button {
                        hex.wrappedValue = ""
                        store.reloadOverrides()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reset to preset default")
                }
            }
        }
    }

    private func rowLabel<C: View>(_ label: String, help: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 16)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private func settingsGroupBox<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DialogColors.light))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DialogColors.border.opacity(0.5), lineWidth: 0.5))
    }

    /// Binding<Color> from hex AppStorage, falls back to preset color
    private func colorBinding(hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding<Color>(
            get: {
                hex.wrappedValue.isEmpty ? fallback : Color(hex: hex.wrappedValue) ?? fallback
            },
            set: { newColor in
                hex.wrappedValue = newColor.toHex() ?? ""
                store.reloadOverrides()
            }
        )
    }
}

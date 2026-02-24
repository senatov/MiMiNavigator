// SettingsColorsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors settings — named color tokens, Light/Dark variants, preset themes.
//   All colors pulled from FilePanelStyle, DesignTokens, DialogColors.
//   Stored in AppStorage as hex strings, applied via ColorThemeStore.

import AppKit
import SwiftUI

// MARK: - Color Theme Model

struct ColorTheme: Identifiable, Equatable {
    let id: String
    let name: String

    // Panel
    var panelBackground: Color
    var panelText: Color
    var dirNameColor: Color
    var fileNameColor: Color
    var symlinkColor: Color

    // Selection
    var selectionActive: Color
    var selectionInactive: Color
    var selectionBorder: Color

    // UI chrome
    var separatorColor: Color
    var dialogBase: Color
    var dialogStripe: Color
    var accentColor: Color
    /// Background of floating dialog windows (Find Files, Settings, etc.)
    /// Matches active panel background, slightly more transparent.
    var dialogBackground: Color

    // Dark variants (nil = same as light)
    var panelBackgroundDark: Color?
    var panelTextDark: Color?
    var dirNameColorDark: Color?
    var selectionActiveDark: Color?
}

// MARK: - Built-in Presets

extension ColorTheme {

    /// Default — matches current hardcoded values exactly
    static let defaultTheme = ColorTheme(
        id: "default",
        name: "Default",
        panelBackground:    Color(nsColor: .controlBackgroundColor),
        panelText:          Color.primary,
        dirNameColor:       Color.primary,
        fileNameColor:      Color.primary,
        symlinkColor:       Color(nsColor: .linkColor),
        selectionActive:    Color(nsColor: .selectedContentBackgroundColor),
        selectionInactive:  Color(nsColor: .unemphasizedSelectedContentBackgroundColor),
        selectionBorder:    Color.accentColor.opacity(0.5),
        separatorColor:     Color(nsColor: .separatorColor),
        dialogBase:         Color(red: 239/255, green: 239/255, blue: 239/255),
        dialogStripe:       Color(red: 231/255, green: 231/255, blue: 231/255),
        accentColor:        Color.accentColor,
        dialogBackground:   Color(red: 239/255, green: 239/255, blue: 239/255),
        panelBackgroundDark: Color(nsColor: .windowBackgroundColor),
        panelTextDark:       Color.primary,
        dirNameColorDark:    Color.primary,
        selectionActiveDark: Color(nsColor: .selectedContentBackgroundColor)
    )

    /// Warm — amber/cream tones like ForkLift's warm mode
    static let warmTheme = ColorTheme(
        id: "warm",
        name: "Warm",
        panelBackground:    Color(red: 252/255, green: 248/255, blue: 240/255),
        panelText:          Color(red: 40/255,  green: 35/255,  blue: 28/255),
        dirNameColor:       Color(red: 80/255,  green: 60/255,  blue: 20/255),
        fileNameColor:      Color(red: 40/255,  green: 35/255,  blue: 28/255),
        symlinkColor:       Color(red: 180/255, green: 100/255, blue: 20/255),
        selectionActive:    Color(red: 255/255, green: 200/255, blue: 100/255),
        selectionInactive:  Color(red: 250/255, green: 235/255, blue: 200/255),
        selectionBorder:    Color(red: 210/255, green: 150/255, blue: 60/255).opacity(0.5),
        separatorColor:     Color(red: 200/255, green: 185/255, blue: 160/255),
        dialogBase:         Color(red: 250/255, green: 245/255, blue: 235/255),
        dialogStripe:       Color(red: 245/255, green: 238/255, blue: 224/255),
        accentColor:        Color(red: 210/255, green: 140/255, blue: 40/255),
        dialogBackground:   Color(red: 252/255, green: 248/255, blue: 240/255).opacity(0.92),
        panelBackgroundDark: Color(red: 40/255, green: 35/255, blue: 28/255),
        panelTextDark:       Color(red: 240/255, green: 225/255, blue: 200/255),
        dirNameColorDark:    Color(red: 255/255, green: 200/255, blue: 120/255),
        selectionActiveDark: Color(red: 100/255, green: 75/255, blue: 30/255)
    )

    /// Midnight — dark blue like Nova / Sublime Text
    static let midnightTheme = ColorTheme(
        id: "midnight",
        name: "Midnight",
        panelBackground:    Color(red: 30/255,  green: 35/255,  blue: 50/255),
        panelText:          Color(red: 210/255, green: 215/255, blue: 230/255),
        dirNameColor:       Color(red: 130/255, green: 180/255, blue: 255/255),
        fileNameColor:      Color(red: 210/255, green: 215/255, blue: 230/255),
        symlinkColor:       Color(red: 100/255, green: 220/255, blue: 200/255),
        selectionActive:    Color(red: 50/255,  green: 80/255,  blue: 130/255),
        selectionInactive:  Color(red: 40/255,  green: 50/255,  blue: 75/255),
        selectionBorder:    Color(red: 80/255,  green: 130/255, blue: 220/255).opacity(0.6),
        separatorColor:     Color(red: 55/255,  green: 65/255,  blue: 90/255),
        dialogBase:         Color(red: 35/255,  green: 40/255,  blue: 58/255),
        dialogStripe:       Color(red: 28/255,  green: 33/255,  blue: 50/255),
        accentColor:        Color(red: 80/255,  green: 150/255, blue: 255/255),
        dialogBackground:   Color(red: 30/255,  green: 35/255,  blue: 50/255).opacity(0.92),
        panelBackgroundDark: nil,
        panelTextDark:       nil,
        dirNameColorDark:    nil,
        selectionActiveDark: nil
    )

    /// Solarized — classic terminal palette
    static let solarizedTheme = ColorTheme(
        id: "solarized",
        name: "Solarized",
        panelBackground:    Color(red: 253/255, green: 246/255, blue: 227/255),
        panelText:          Color(red: 101/255, green: 123/255, blue: 131/255),
        dirNameColor:       Color(red: 38/255,  green: 139/255, blue: 210/255),
        fileNameColor:      Color(red: 101/255, green: 123/255, blue: 131/255),
        symlinkColor:       Color(red: 42/255,  green: 161/255, blue: 152/255),
        selectionActive:    Color(red: 238/255, green: 232/255, blue: 213/255),
        selectionInactive:  Color(red: 147/255, green: 161/255, blue: 161/255).opacity(0.2),
        selectionBorder:    Color(red: 38/255,  green: 139/255, blue: 210/255).opacity(0.4),
        separatorColor:     Color(red: 147/255, green: 161/255, blue: 161/255).opacity(0.5),
        dialogBase:         Color(red: 250/255, green: 244/255, blue: 222/255),
        dialogStripe:       Color(red: 245/255, green: 238/255, blue: 214/255),
        accentColor:        Color(red: 38/255,  green: 139/255, blue: 210/255),
        dialogBackground:   Color(red: 253/255, green: 246/255, blue: 227/255).opacity(0.92),
        panelBackgroundDark: Color(red: 0/255,   green: 43/255,  blue: 54/255),
        panelTextDark:       Color(red: 131/255, green: 148/255, blue: 150/255),
        dirNameColorDark:    Color(red: 38/255,  green: 139/255, blue: 210/255),
        selectionActiveDark: Color(red: 7/255,   green: 54/255,  blue: 66/255)
    )

    static let allPresets: [ColorTheme] = [.defaultTheme, .warmTheme, .midnightTheme, .solarizedTheme]
}

// MARK: - ColorThemeStore (singleton, @Observable)

@MainActor
@Observable
final class ColorThemeStore {
    static let shared = ColorThemeStore()

    @ObservationIgnored
    @AppStorage("settings.colorTheme.id") private var savedThemeID: String = "default"

    @ObservationIgnored
    @AppStorage("settings.colors.useDarkVariant") var useDarkVariant: Bool = false

    // Custom overrides (hex per token)
    @ObservationIgnored @AppStorage("color.panelBackground")   var hexPanelBg: String = ""
    @ObservationIgnored @AppStorage("color.panelText")         var hexPanelText: String = ""
    @ObservationIgnored @AppStorage("color.dirName")           var hexDirName: String = ""
    @ObservationIgnored @AppStorage("color.fileName")          var hexFileName: String = ""
    @ObservationIgnored @AppStorage("color.symlink")           var hexSymlink: String = ""
    @ObservationIgnored @AppStorage("color.selectionActive")   var hexSelActive: String = ""
    @ObservationIgnored @AppStorage("color.selectionInactive") var hexSelInactive: String = ""
    @ObservationIgnored @AppStorage("color.selectionBorder")   var hexSelBorder: String = ""
    @ObservationIgnored @AppStorage("color.separator")         var hexSeparator: String = ""
    @ObservationIgnored @AppStorage("color.dialogBase")        var hexDialogBase: String = ""
    @ObservationIgnored @AppStorage("color.dialogStripe")      var hexDialogStripe: String = ""
    @ObservationIgnored @AppStorage("color.accent")            var hexAccent: String = ""
    @ObservationIgnored @AppStorage("color.dialogBackground")  var hexDialogBackground: String = ""

    private(set) var activeTheme: ColorTheme = .defaultTheme

    private init() {
        loadTheme(id: savedThemeID)
    }

    func loadTheme(id: String) {
        let base = ColorTheme.allPresets.first { $0.id == id } ?? .defaultTheme
        savedThemeID = base.id
        // Apply custom overrides on top of preset
        activeTheme = base
        log.info("[ColorTheme] loaded '\(base.name)'")
    }

    func applyPreset(_ theme: ColorTheme) {
        // Reset all custom overrides
        hexPanelBg = ""; hexPanelText = ""; hexDirName = ""; hexFileName = ""
        hexSymlink = ""; hexSelActive = ""; hexSelInactive = ""; hexSelBorder = ""
        hexSeparator = ""; hexDialogBase = ""; hexDialogStripe = ""; hexAccent = ""
        loadTheme(id: theme.id)
    }
}

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
    @AppStorage("color.accent")            private var hexAccent: String = ""
    @AppStorage("color.dialogBackground")  private var hexDialogBg: String = ""

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

            // ── Reset ─────────────────────────────────────────
            HStack {
                Spacer()
                Button("Reset to Default") {
                    selectedPresetID = "default"
                    store.applyPreset(.defaultTheme)
                }
                .buttonStyle(.bordered)
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
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
    }

    /// Binding<Color> from hex AppStorage, falls back to preset color
    private func colorBinding(hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding<Color>(
            get: {
                hex.wrappedValue.isEmpty ? fallback : Color(hex: hex.wrappedValue) ?? fallback
            },
            set: { newColor in
                hex.wrappedValue = newColor.toHex() ?? ""
            }
        )
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double((val >>  0) & 0xFF) / 255
        )
    }

    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

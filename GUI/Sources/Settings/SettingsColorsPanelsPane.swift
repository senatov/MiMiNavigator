// SettingsColorsPanelsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Colors › "Panels & Files" — panel bg/text, selection,
//   file states, column colors, theme preset picker.

import SwiftUI

// MARK: - SettingsColorsPanelsPane
struct SettingsColorsPanelsPane: View, ColorPaneHelpers {

    @State private var store = ColorThemeStore.shared
    @State private var selectedPresetID = ColorThemeStore.shared.activeTheme.id
    @State private var useDarkVariant   = ColorThemeStore.shared.useDarkVariant

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
    @AppStorage("color.hiddenFile")        private var hexHiddenFile: String = ""
    @AppStorage("color.markedFile")        private var hexMarkedFile: String = ""
    @AppStorage("color.parentEntry")       private var hexParentEntry: String = ""
    @AppStorage("color.archivePath")       private var hexArchivePath: String = ""
    @AppStorage("color.markedCount")       private var hexMarkedCount: String = ""
    @AppStorage("color.columnName")        private var hexColumnName: String = ""
    @AppStorage("color.columnSize")        private var hexColumnSize: String = ""
    @AppStorage("color.columnKind")        private var hexColumnKind: String = ""
    @AppStorage("color.columnDate")        private var hexColumnDate: String = ""
    @AppStorage("color.columnPermissions") private var hexColumnPermissions: String = ""
    @AppStorage("color.columnOwner")       private var hexColumnOwner: String = ""
    @AppStorage("color.columnGroup")       private var hexColumnGroup: String = ""
    @AppStorage("color.columnChildCount")  private var hexColumnChildCount: String = ""

    private var preset: ColorTheme {
        store.effectivePreset(id: selectedPresetID)
    }

    private struct SelectionColorItem {
        let title: String
        let help: String
        let fallback: Color
        let hex: Binding<String>
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Theme Preset Picker ─────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    rowLabel("Theme preset:", help: "Built-in color theme as starting point") {
                        HStack(spacing: 10) {
                            Picker("", selection: $selectedPresetID) {
                                ForEach(ColorTheme.allPresets) { t in Text(t.name).tag(t.id) }
                            }
                            .labelsHidden().frame(width: 150)
                            .onChange(of: selectedPresetID) { _, id in
                                store.applyPreset(ColorTheme.allPresets.first { $0.id == id } ?? .defaultTheme)
                            }
                            HStack(spacing: 4) {
                                swatch(preset.panelBackground, label: "BG")
                                swatch(preset.panelText,       label: "Txt")
                                swatch(preset.dirNameColor,    label: "Dir")
                                swatch(preset.selectionActive, label: "Sel")
                                swatch(preset.accentColor,     label: "Acc")
                            }
                        }
                    }
                    Divider()
                    rowLabel("Dark variant:", help: "Separate dark-mode color set") {
                        Toggle("Use separate dark-mode colors", isOn: $useDarkVariant)
                            .toggleStyle(.checkbox)
                            .onChange(of: useDarkVariant) { _, v in store.useDarkVariant = v }
                    }
                }
            }

            // ── Panel ──────────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Panel")
                    colorRow("Background", help: "File list panel background",
                             preset: preset.panelBackground, hex: $hexPanelBg, store: store)
                    Divider()
                    colorRow("File name",  help: "Regular file text color",
                             preset: preset.fileNameColor, hex: $hexFileName, store: store)
                    Divider()
                    colorRow("Directory",  help: "Directory name text color",
                             preset: preset.dirNameColor, hex: $hexDirName, store: store)
                    Divider()
                    colorRow("Symlink",    help: "Symbolic link name color",
                             preset: preset.symlinkColor, hex: $hexSymlink, store: store)
                    Divider()
                    colorRow("Accent",     help: "Buttons, highlights, active borders",
                             preset: preset.accentColor, hex: $hexAccent, store: store)
                    Divider()
                    colorRow("Dialog background", help: "Settings / Find Files floating panel bg",
                             preset: preset.dialogBackground, hex: $hexDialogBg, store: store)
                }
            }

            // ── Selection ──────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Selection")
                    selectionColorRow(
                        .init(
                            title: "Active",
                            help: "Selected row — focused panel",
                            fallback: preset.selectionActive,
                            hex: $hexSelActive
                        )
                    )
                    Divider()
                    selectionColorRow(
                        .init(
                            title: "Inactive",
                            help: "Selected row — unfocused panel",
                            fallback: preset.selectionInactive,
                            hex: $hexSelInactive
                        )
                    )
                    Divider()
                    selectionColorRow(
                        .init(
                            title: "Border",
                            help: "Top/bottom lines of selected row",
                            fallback: preset.selectionBorder,
                            hex: $hexSelBorder
                        )
                    )
                    Divider()
                    selectionLineWidthRow
                }
            }

            // ── File States ────────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("File States")
                    colorRow("Hidden files", help: ".dotfile dimmed text",
                             preset: preset.hiddenFileColor,  hex: $hexHiddenFile,  store: store)
                    Divider()
                    colorRow("Marked files", help: "TC-style marked text (Insert key)",
                             preset: preset.markedFileColor,  hex: $hexMarkedFile,  store: store)
                    Divider()
                    colorRow("Parent entry", help: "'..' row color",
                             preset: preset.parentEntryColor, hex: $hexParentEntry, store: store)
                    Divider()
                    colorRow("Archive path", help: "Files inside open archives",
                             preset: preset.archivePathColor, hex: $hexArchivePath, store: store)
                    Divider()
                    colorRow("Marked count", help: "Status bar marked-files counter",
                             preset: preset.markedCountColor, hex: $hexMarkedCount, store: store)
                }
            }

            // ── Column Colors ──────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    sectionHeader("Column Colors")
                    colorRow("Name",        help: "Name column text accent",
                             preset: preset.columnNameColor,        hex: $hexColumnName,        store: store)
                    Divider()
                    colorRow("Size",        help: "Size column text accent",
                             preset: preset.columnSizeColor,        hex: $hexColumnSize,        store: store)
                    Divider()
                    colorRow("Kind",        help: "Kind column text accent",
                             preset: preset.columnKindColor,        hex: $hexColumnKind,        store: store)
                    Divider()
                    colorRow("Date",        help: "All date columns text accent",
                             preset: preset.columnDateColor,        hex: $hexColumnDate,        store: store)
                    Divider()
                    colorRow("Permissions", help: "Permissions column",
                             preset: preset.columnPermissionsColor, hex: $hexColumnPermissions, store: store)
                    Divider()
                    colorRow("Owner",       help: "Owner column",
                             preset: preset.columnOwnerColor,       hex: $hexColumnOwner,       store: store)
                    Divider()
                    colorRow("Group",       help: "Group column",
                             preset: preset.columnGroupColor,       hex: $hexColumnGroup,       store: store)
                    Divider()
                    colorRow("# Count",     help: "Child count column",
                             preset: preset.columnChildCountColor,  hex: $hexColumnChildCount,  store: store)
                }
            }

            resetButton {
                selectedPresetID = "default"
                store.applyPreset(.defaultTheme)
            }
        }
    }

    private func selectionColorRow(_ item: SelectionColorItem) -> some View {
        rowLabel("\(item.title):", help: item.help) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(item.fallback)
                    .frame(width: 22, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                    .help("Preset default")
                Text("→").foregroundStyle(.tertiary).font(.system(size: 11))
                ColorPicker("", selection: selectionColorBinding(hex: item.hex, fallback: item.fallback))
                    .labelsHidden().frame(width: 28)
                if !item.hex.wrappedValue.isEmpty {
                    Button {
                        item.hex.wrappedValue = ""
                        syncSelectionDefaults()
                        store.reloadOverrides()
                    } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reset to preset default")
                }
            }
        }
    }

    private var selectionLineWidthRow: some View {
        rowLabel("Line width:", help: "Selection border thickness") {
            HStack(spacing: 10) {
                Slider(value: $selLineWidth, in: 0.5...4.0, step: 0.5)
                    .frame(width: 130)
                    .onChange(of: selLineWidth) { _, newValue in
                        store.updateSelectionDefaults(lineWidth: newValue)
                        store.reloadOverrides()
                    }
                Text(String(format: "%.1f", selLineWidth))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
        }
    }

    private func selectionColorBinding(hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding<Color>(
            get: {
                hex.wrappedValue.isEmpty ? fallback : Color(hex: hex.wrappedValue) ?? fallback
            },
            set: { newColor in
                hex.wrappedValue = newColor.toHex() ?? ""
                syncSelectionDefaults()
                store.reloadOverrides()
            }
        )
    }

    private func syncSelectionDefaults() {
        let active = Color(hex: hexSelActive) ?? preset.selectionActive
        let inactive = Color(hex: hexSelInactive) ?? preset.selectionInactive
        let border = Color(hex: hexSelBorder) ?? preset.selectionBorder
        store.updateSelectionDefaults(
            active: active,
            inactive: inactive,
            border: border,
            lineWidth: selLineWidth
        )
    }
}

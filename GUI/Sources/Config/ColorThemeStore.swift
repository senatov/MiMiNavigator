// ColorThemeStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Color theme persistence (extracted from SettingsColorsPane)

import SwiftUI

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
    @ObservationIgnored @AppStorage("color.panelBackground") var hexPanelBg: String = ""
    @ObservationIgnored @AppStorage("color.panelText") var hexPanelText: String = ""
    @ObservationIgnored @AppStorage("color.dirName") var hexDirName: String = ""
    @ObservationIgnored @AppStorage("color.fileName") var hexFileName: String = ""
    @ObservationIgnored @AppStorage("color.symlink") var hexSymlink: String = ""
    @ObservationIgnored @AppStorage("color.selectionActive") var hexSelActive: String = ""
    @ObservationIgnored @AppStorage("color.selectionInactive") var hexSelInactive: String = ""
    @ObservationIgnored @AppStorage("color.selectionBorder") var hexSelBorder: String = ""
    @ObservationIgnored @AppStorage("default.color.selectionActive") private var defaultHexSelActive: String = ""
    @ObservationIgnored @AppStorage("default.color.selectionInactive") private var defaultHexSelInactive: String = ""
    @ObservationIgnored @AppStorage("default.color.selectionBorder") private var defaultHexSelBorder: String = ""
    @ObservationIgnored @AppStorage("default.selection.lineWidth") private var defaultStoredLineWidth: Double = 0
    @ObservationIgnored @AppStorage("color.separator") var hexSeparator: String = ""
    @ObservationIgnored @AppStorage("color.dialogBase") var hexDialogBase: String = ""
    @ObservationIgnored @AppStorage("color.dialogStripe") var hexDialogStripe: String = ""
    @ObservationIgnored @AppStorage("color.accent") var hexAccent: String = ""
    @ObservationIgnored @AppStorage("color.dialogBackground") var hexDialogBackground: String = ""

    // New extended color tokens
    @ObservationIgnored @AppStorage("color.hiddenFile") var hexHiddenFile: String = ""
    @ObservationIgnored @AppStorage("color.markedFile") var hexMarkedFile: String = ""
    @ObservationIgnored @AppStorage("color.parentEntry") var hexParentEntry: String = ""
    @ObservationIgnored @AppStorage("color.archivePath") var hexArchivePath: String = ""
    @ObservationIgnored @AppStorage("color.markedCount") var hexMarkedCount: String = ""
    @ObservationIgnored @AppStorage("color.columnName") var hexColumnName: String = ""
    @ObservationIgnored @AppStorage("color.columnSize") var hexColumnSize: String = ""
    @ObservationIgnored @AppStorage("color.columnKind") var hexColumnKind: String = ""
    @ObservationIgnored @AppStorage("color.columnDate") var hexColumnDate: String = ""
    @ObservationIgnored @AppStorage("color.columnPermissions") var hexColumnPermissions: String = ""
    @ObservationIgnored @AppStorage("color.columnOwner") var hexColumnOwner: String = ""
    @ObservationIgnored @AppStorage("color.columnGroup") var hexColumnGroup: String = ""
    @ObservationIgnored @AppStorage("color.columnChildCount") var hexColumnChildCount: String = ""
    @ObservationIgnored @AppStorage("color.columnDivider") var hexColumnDivider: String = ""
    @ObservationIgnored @AppStorage("color.dividerNormal") var hexDividerNormal: String = ""
    @ObservationIgnored @AppStorage("color.dividerActive") var hexDividerActive: String = ""
    @ObservationIgnored @AppStorage("color.panelBorderActive") var hexPanelBorderActive: String = ""
    @ObservationIgnored @AppStorage("color.panelBorderInactive") var hexPanelBorderInactive: String = ""
    @ObservationIgnored @AppStorage("panel.borderWidth") var storedPanelBorderWidth: Double = 0
    @ObservationIgnored @AppStorage("color.warmWhite") var hexWarmWhite: String = ""
    @ObservationIgnored @AppStorage("color.zebraActiveEven") var hexZebraActiveEven: String = ""
    @ObservationIgnored @AppStorage("color.zebraActiveOdd") var hexZebraActiveOdd: String = ""
    @ObservationIgnored @AppStorage("color.zebraInactiveEven") var hexZebraInactiveEven: String = ""
    @ObservationIgnored @AppStorage("color.zebraInactiveOdd") var hexZebraInactiveOdd: String = ""
    @ObservationIgnored @AppStorage("color.filterActive") var hexFilterActive: String = ""

    // BreadCrumb appearance
    @ObservationIgnored @AppStorage("color.breadcrumbTextActive") var hexBreadcrumbTextActive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbTextInactive") var hexBreadcrumbTextInactive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbBgActive") var hexBreadcrumbBgActive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbBgInactive") var hexBreadcrumbBgInactive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbVariable") var hexBreadcrumbVariable: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbHoverText") var hexBreadcrumbHoverText: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbHoverBackground") var hexBreadcrumbHoverBackground: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbHoverBorder") var hexBreadcrumbHoverBorder: String = ""
    @ObservationIgnored @AppStorage("breadcrumb.fontSize") var breadcrumbFontSize: Double = 0
    @ObservationIgnored @AppStorage("breadcrumb.hoverFontSize") var breadcrumbHoverFontSize: Double = 0
    @ObservationIgnored @AppStorage("breadcrumb.variableItalic") var breadcrumbVariableItalic: Bool = true

    static let defaultBreadcrumbHoverText = Color(#colorLiteral(red: 0.000, green: 0.325, blue: 0.573, alpha: 1))
    static let defaultBreadcrumbHoverBackground = Color(#colorLiteral(red: 0.918, green: 0.918, blue: 0.918, alpha: 1))
    static let defaultBreadcrumbHoverBorder = Color(#colorLiteral(red: 0.835, green: 0.835, blue: 0.835, alpha: 1))

    var breadcrumbHoverTextColor: Color {
        Color(hex: ud("color.breadcrumbHoverText")) ?? Self.defaultBreadcrumbHoverText
    }

    var breadcrumbHoverBackgroundColor: Color {
        Color(hex: ud("color.breadcrumbHoverBackground")) ?? Self.defaultBreadcrumbHoverBackground
    }

    var breadcrumbHoverBorderColor: Color {
        Color(hex: ud("color.breadcrumbHoverBorder")) ?? Self.defaultBreadcrumbHoverBorder
    }

    var effectiveBreadcrumbHoverFontSize: CGFloat {
        let stored = udD("breadcrumb.hoverFontSize")
        let requestedSize = stored > 0 ? CGFloat(stored) : activeTheme.breadcrumbFontSize + 1
        return (requestedSize * 2).rounded() / 2
    }

    // Button appearance
    @ObservationIgnored @AppStorage("button.borderColor") var hexButtonBorder: String = ""
    @ObservationIgnored @AppStorage("button.borderWidth") var buttonBorderWidth: Double = 0.5
    @ObservationIgnored @AppStorage("button.cornerRadius") var buttonCornerRadius: Double = 6.0
    @ObservationIgnored @AppStorage("button.shadowColor") var hexButtonShadow: String = ""
    @ObservationIgnored @AppStorage("button.shadowRadius") var buttonShadowRadius: Double = 1.0
    @ObservationIgnored @AppStorage("button.shadowY") var buttonShadowY: Double = 1.5

    private(set) var activeTheme: ColorTheme = .defaultTheme

    /// Version counter — increments on every theme change, triggers SwiftUI updates
    private(set) var themeVersion: Int = 0

    private init() {
        migrateLegacyZebraOverrides()
        loadTheme(id: savedThemeID)
    }

    private func migrateLegacyZebraOverrides() {
        let defaults = UserDefaults.standard
        guard let even = defaults.string(forKey: "color.zebraActiveEven")?.uppercased(),
              let odd = defaults.string(forKey: "color.zebraActiveOdd")?.uppercased()
        else { return }
        let legacyPairs = [
            ("FEFFFF", "F6F6F6"),
            ("FFFFFF", "F1F1F1"),
        ]
        guard legacyPairs.contains(where: { $0 == (even, odd) }) else { return }
        defaults.removeObject(forKey: "color.zebraActiveEven")
        defaults.removeObject(forKey: "color.zebraActiveOdd")
        log.info("[ColorTheme] removed legacy low-contrast active zebra overrides")
    }

    func loadTheme(id: String) {
        let base = baseTheme(for: id)
        savedThemeID = base.id
        // Apply custom hex overrides on top of preset
        activeTheme = applyOverrides(to: base)
        log.info("[ColorTheme] loaded '\(base.name)' with \(countOverrides()) custom override(s)")
    }

    // MARK: - Read hex straight from UserDefaults (bypass stale @AppStorage cache)

    private func ud(_ key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    private func udD(_ key: String, fallback: Double = 0) -> Double {
        let v = UserDefaults.standard.double(forKey: key)
        return v != 0 ? v : fallback
    }

    private func baseTheme(for id: String) -> ColorTheme {
        let preset = ColorTheme.allPresets.first { $0.id == id } ?? .defaultTheme
        guard preset.id == ColorTheme.defaultTheme.id else { return preset }
        return applyDefaultSelectionOverrides(to: preset)
    }

    private func applyDefaultSelectionOverrides(to base: ColorTheme) -> ColorTheme {
        var theme = base
        if let c = Color(hex: defaultHexSelActive) { theme.selectionActive = c }
        if let c = Color(hex: defaultHexSelInactive) { theme.selectionInactive = c }
        if let c = Color(hex: defaultHexSelBorder) { theme.selectionBorder = c }
        if defaultStoredLineWidth > 0 {
            theme.selectionLineWidth = CGFloat(defaultStoredLineWidth)
        }
        return theme
    }

    func effectivePreset(id: String) -> ColorTheme {
        baseTheme(for: id)
    }

    func updateSelectionDefaults(
        active: Color? = nil,
        inactive: Color? = nil,
        border: Color? = nil,
        lineWidth: Double? = nil
    ) {
        if let active { defaultHexSelActive = active.toHex() ?? defaultHexSelActive }
        if let inactive { defaultHexSelInactive = inactive.toHex() ?? defaultHexSelInactive }
        if let border { defaultHexSelBorder = border.toHex() ?? defaultHexSelBorder }
        if let lineWidth { defaultStoredLineWidth = lineWidth }
        if savedThemeID == ColorTheme.defaultTheme.id {
            reloadOverrides()
        }
    }

    // MARK: - Apply hex overrides to base theme

    private func applyOverrides(to base: ColorTheme) -> ColorTheme {
        var theme = base
        let colorOverrides: [(String, WritableKeyPath<ColorTheme, Color>)] = [
            ("color.panelBackground", \.panelBackground), ("color.panelText", \.panelText),
            ("color.dirName", \.dirNameColor), ("color.fileName", \.fileNameColor),
            ("color.symlink", \.symlinkColor), ("color.selectionActive", \.selectionActive),
            ("color.selectionInactive", \.selectionInactive), ("color.selectionBorder", \.selectionBorder),
            ("color.separator", \.separatorColor), ("color.dialogBase", \.dialogBase),
            ("color.dialogStripe", \.dialogStripe), ("color.accent", \.accentColor),
            ("color.dialogBackground", \.dialogBackground), ("color.hiddenFile", \.hiddenFileColor),
            ("color.markedFile", \.markedFileColor), ("color.parentEntry", \.parentEntryColor),
            ("color.archivePath", \.archivePathColor), ("color.markedCount", \.markedCountColor),
            ("color.columnName", \.columnNameColor), ("color.columnSize", \.columnSizeColor),
            ("color.columnKind", \.columnKindColor), ("color.columnDate", \.columnDateColor),
            ("color.columnPermissions", \.columnPermissionsColor), ("color.columnOwner", \.columnOwnerColor),
            ("color.columnGroup", \.columnGroupColor), ("color.columnChildCount", \.columnChildCountColor),
            ("color.columnDivider", \.columnDividerColor), ("color.dividerNormal", \.dividerNormalColor),
            ("color.dividerActive", \.dividerActiveColor), ("color.panelBorderActive", \.panelBorderActive),
            ("color.panelBorderInactive", \.panelBorderInactive), ("color.warmWhite", \.warmWhite),
            ("color.zebraActiveEven", \.zebraActiveEven), ("color.zebraActiveOdd", \.zebraActiveOdd),
            ("color.zebraInactiveEven", \.zebraInactiveEven), ("color.zebraInactiveOdd", \.zebraInactiveOdd),
            ("color.filterActive", \.filterActiveColor), ("color.breadcrumbTextActive", \.breadcrumbTextActive),
            ("color.breadcrumbTextInactive", \.breadcrumbTextInactive),
            ("color.breadcrumbBgActive", \.breadcrumbBgActive),
            ("color.breadcrumbBgInactive", \.breadcrumbBgInactive),
            ("color.breadcrumbVariable", \.breadcrumbVariableColor),
        ]
        for (key, keyPath) in colorOverrides {
            if let color = Color(hex: ud(key)) {
                theme[keyPath: keyPath] = color
            }
        }
        theme.selectionLineWidth = CGFloat(
            udD("selection.lineWidth", fallback: Double(base.selectionLineWidth))
        )
        let bw = udD("panel.borderWidth")
        if bw > 0 { theme.panelBorderWidth = CGFloat(bw) }
        let fs = udD("breadcrumb.fontSize")
        if fs > 0 { theme.breadcrumbFontSize = CGFloat(fs) }
        return theme
    }

    // MARK: - Count active overrides

    private func countOverrides() -> Int {
        let keys = [
            "color.panelBackground", "color.panelText", "color.dirName", "color.fileName",
            "color.symlink", "color.selectionActive", "color.selectionInactive", "color.selectionBorder",
            "color.separator", "color.dialogBase", "color.dialogStripe", "color.accent", "color.dialogBackground",
            "color.hiddenFile", "color.markedFile", "color.parentEntry", "color.archivePath", "color.markedCount",
            "color.columnName", "color.columnSize", "color.columnKind", "color.columnDate",
            "color.columnPermissions", "color.columnOwner", "color.columnGroup", "color.columnChildCount",
            "color.columnDivider", "color.dividerNormal", "color.dividerActive", "color.panelBorderActive", "color.panelBorderInactive",
            "color.warmWhite", "color.zebraActiveEven", "color.zebraActiveOdd",
            "color.zebraInactiveEven", "color.zebraInactiveOdd", "color.filterActive",
            "color.breadcrumbTextActive", "color.breadcrumbTextInactive",
            "color.breadcrumbBgActive", "color.breadcrumbBgInactive", "color.breadcrumbVariable",
            "color.breadcrumbHoverText", "color.breadcrumbHoverBackground", "color.breadcrumbHoverBorder",
        ]
        return keys.filter { !ud($0).isEmpty }.count
    }

    // MARK: - Reload overrides on top of current preset

    func reloadOverrides() {
        let base = baseTheme(for: savedThemeID)
        activeTheme = applyOverrides(to: base)
        themeVersion += 1
        log.debug("[ColorTheme] reloaded v\(themeVersion)")
    }

    // MARK: - Apply preset

    func applyPreset(_ theme: ColorTheme) {
        // Reset all custom overrides — original 13 tokens
        hexPanelBg = ""; hexPanelText = ""; hexDirName = ""; hexFileName = ""
        hexSymlink = ""; hexSelActive = ""; hexSelInactive = ""; hexSelBorder = ""
        hexSeparator = ""; hexDialogBase = ""; hexDialogStripe = ""; hexAccent = ""
        hexDialogBackground = ""
        // Extended 15 tokens
        hexHiddenFile = ""; hexMarkedFile = ""; hexParentEntry = ""
        hexArchivePath = ""; hexMarkedCount = ""
        hexColumnName = ""; hexColumnSize = ""; hexColumnKind = ""; hexColumnDate = ""
        hexColumnPermissions = ""; hexColumnOwner = ""; hexColumnGroup = ""; hexColumnChildCount = ""
        hexColumnDivider = ""
        hexDividerNormal = ""; hexDividerActive = ""
        hexPanelBorderActive = ""; hexPanelBorderInactive = ""
        storedPanelBorderWidth = 0
        hexWarmWhite = ""
        hexZebraActiveEven = ""; hexZebraActiveOdd = ""
        hexZebraInactiveEven = ""; hexZebraInactiveOdd = ""
        hexFilterActive = ""
        hexBreadcrumbTextActive = ""; hexBreadcrumbTextInactive = ""
        hexBreadcrumbBgActive = ""; hexBreadcrumbBgInactive = ""
        hexBreadcrumbVariable = ""
        hexBreadcrumbHoverText = ""; hexBreadcrumbHoverBackground = ""
        hexBreadcrumbHoverBorder = ""
        breadcrumbFontSize = 0
        breadcrumbHoverFontSize = 0
        breadcrumbVariableItalic = true
        loadTheme(id: theme.id)
    }
}

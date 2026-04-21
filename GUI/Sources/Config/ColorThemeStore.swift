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
    @ObservationIgnored @AppStorage("color.panelBackground")   var hexPanelBg: String = ""
    @ObservationIgnored @AppStorage("color.panelText")         var hexPanelText: String = ""
    @ObservationIgnored @AppStorage("color.dirName")           var hexDirName: String = ""
    @ObservationIgnored @AppStorage("color.fileName")          var hexFileName: String = ""
    @ObservationIgnored @AppStorage("color.symlink")           var hexSymlink: String = ""
    @ObservationIgnored @AppStorage("color.selectionActive")   var hexSelActive: String = ""
    @ObservationIgnored @AppStorage("color.selectionInactive") var hexSelInactive: String = ""
    @ObservationIgnored @AppStorage("color.selectionBorder")   var hexSelBorder: String = ""
    @ObservationIgnored @AppStorage("selection.lineWidth")     var storedLineWidth: Double = 2.0
    @ObservationIgnored @AppStorage("default.color.selectionActive")   private var defaultHexSelActive: String = ""
    @ObservationIgnored @AppStorage("default.color.selectionInactive") private var defaultHexSelInactive: String = ""
    @ObservationIgnored @AppStorage("default.color.selectionBorder")   private var defaultHexSelBorder: String = ""
    @ObservationIgnored @AppStorage("default.selection.lineWidth")     private var defaultStoredLineWidth: Double = 0
    @ObservationIgnored @AppStorage("color.separator")         var hexSeparator: String = ""
    @ObservationIgnored @AppStorage("color.dialogBase")        var hexDialogBase: String = ""
    @ObservationIgnored @AppStorage("color.dialogStripe")      var hexDialogStripe: String = ""
    @ObservationIgnored @AppStorage("color.accent")            var hexAccent: String = ""
    @ObservationIgnored @AppStorage("color.dialogBackground")  var hexDialogBackground: String = ""

    // New extended color tokens
    @ObservationIgnored @AppStorage("color.hiddenFile")       var hexHiddenFile: String = ""
    @ObservationIgnored @AppStorage("color.markedFile")       var hexMarkedFile: String = ""
    @ObservationIgnored @AppStorage("color.parentEntry")      var hexParentEntry: String = ""
    @ObservationIgnored @AppStorage("color.archivePath")      var hexArchivePath: String = ""
    @ObservationIgnored @AppStorage("color.markedCount")      var hexMarkedCount: String = ""
    @ObservationIgnored @AppStorage("color.columnName")       var hexColumnName: String = ""
    @ObservationIgnored @AppStorage("color.columnSize")       var hexColumnSize: String = ""
    @ObservationIgnored @AppStorage("color.columnKind")       var hexColumnKind: String = ""
    @ObservationIgnored @AppStorage("color.columnDate")       var hexColumnDate: String = ""
    @ObservationIgnored @AppStorage("color.columnPermissions") var hexColumnPermissions: String = ""
    @ObservationIgnored @AppStorage("color.columnOwner")       var hexColumnOwner: String = ""
    @ObservationIgnored @AppStorage("color.columnGroup")       var hexColumnGroup: String = ""
    @ObservationIgnored @AppStorage("color.columnChildCount")  var hexColumnChildCount: String = ""
    @ObservationIgnored @AppStorage("color.dividerNormal")    var hexDividerNormal: String = ""
    @ObservationIgnored @AppStorage("color.dividerActive")    var hexDividerActive: String = ""
    @ObservationIgnored @AppStorage("color.panelBorderActive")   var hexPanelBorderActive: String = ""
    @ObservationIgnored @AppStorage("color.panelBorderInactive") var hexPanelBorderInactive: String = ""
    @ObservationIgnored @AppStorage("panel.borderWidth")         var storedPanelBorderWidth: Double = 0
    @ObservationIgnored @AppStorage("color.warmWhite")        var hexWarmWhite: String = ""
    @ObservationIgnored @AppStorage("color.zebraActiveEven")   var hexZebraActiveEven: String = ""
    @ObservationIgnored @AppStorage("color.zebraActiveOdd")    var hexZebraActiveOdd: String = ""
    @ObservationIgnored @AppStorage("color.zebraInactiveEven") var hexZebraInactiveEven: String = ""
    @ObservationIgnored @AppStorage("color.zebraInactiveOdd")  var hexZebraInactiveOdd: String = ""
    @ObservationIgnored @AppStorage("color.filterActive")     var hexFilterActive: String = ""

    // BreadCrumb appearance
    @ObservationIgnored @AppStorage("color.breadcrumbTextActive")   var hexBreadcrumbTextActive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbTextInactive") var hexBreadcrumbTextInactive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbBgActive")     var hexBreadcrumbBgActive: String = ""
    @ObservationIgnored @AppStorage("color.breadcrumbBgInactive")   var hexBreadcrumbBgInactive: String = ""
    @ObservationIgnored @AppStorage("breadcrumb.fontSize")          var breadcrumbFontSize: Double = 0

    // Button appearance
    @ObservationIgnored @AppStorage("button.borderColor")    var hexButtonBorder: String = ""
    @ObservationIgnored @AppStorage("button.borderWidth")    var buttonBorderWidth: Double = 0.5
    @ObservationIgnored @AppStorage("button.cornerRadius")   var buttonCornerRadius: Double = 6.0
    @ObservationIgnored @AppStorage("button.shadowColor")    var hexButtonShadow: String = ""
    @ObservationIgnored @AppStorage("button.shadowRadius")   var buttonShadowRadius: Double = 1.0
    @ObservationIgnored @AppStorage("button.shadowY")        var buttonShadowY: Double = 0.5

    private(set) var activeTheme: ColorTheme = .defaultTheme
    
    /// Version counter — increments on every theme change, triggers SwiftUI updates
    private(set) var themeVersion: Int = 0

    private init() {
        loadTheme(id: savedThemeID)
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
        if let c = Color(hex: ud("color.panelBackground"))   { theme.panelBackground = c }
        if let c = Color(hex: ud("color.panelText"))         { theme.panelText = c }
        if let c = Color(hex: ud("color.dirName"))           { theme.dirNameColor = c }
        if let c = Color(hex: ud("color.fileName"))          { theme.fileNameColor = c }
        if let c = Color(hex: ud("color.symlink"))           { theme.symlinkColor = c }
        if let c = Color(hex: ud("color.selectionActive"))   { theme.selectionActive = c }
        if let c = Color(hex: ud("color.selectionInactive")) { theme.selectionInactive = c }
        if let c = Color(hex: ud("color.selectionBorder"))   { theme.selectionBorder = c }
        theme.selectionLineWidth = CGFloat(
            udD("selection.lineWidth", fallback: Double(base.selectionLineWidth))
        )
        if let c = Color(hex: ud("color.separator"))         { theme.separatorColor = c }
        if let c = Color(hex: ud("color.dialogBase"))        { theme.dialogBase = c }
        if let c = Color(hex: ud("color.dialogStripe"))      { theme.dialogStripe = c }
        if let c = Color(hex: ud("color.accent"))            { theme.accentColor = c }
        if let c = Color(hex: ud("color.dialogBackground"))  { theme.dialogBackground = c }
        // Extended tokens
        if let c = Color(hex: ud("color.hiddenFile"))        { theme.hiddenFileColor = c }
        if let c = Color(hex: ud("color.markedFile"))        { theme.markedFileColor = c }
        if let c = Color(hex: ud("color.parentEntry"))       { theme.parentEntryColor = c }
        if let c = Color(hex: ud("color.archivePath"))       { theme.archivePathColor = c }
        if let c = Color(hex: ud("color.markedCount"))       { theme.markedCountColor = c }
        if let c = Color(hex: ud("color.columnName"))        { theme.columnNameColor = c }
        if let c = Color(hex: ud("color.columnSize"))        { theme.columnSizeColor = c }
        if let c = Color(hex: ud("color.columnKind"))        { theme.columnKindColor = c }
        if let c = Color(hex: ud("color.columnDate"))        { theme.columnDateColor = c }
        if let c = Color(hex: ud("color.columnPermissions")) { theme.columnPermissionsColor = c }
        if let c = Color(hex: ud("color.columnOwner"))       { theme.columnOwnerColor = c }
        if let c = Color(hex: ud("color.columnGroup"))       { theme.columnGroupColor = c }
        if let c = Color(hex: ud("color.columnChildCount"))  { theme.columnChildCountColor = c }
        if let c = Color(hex: ud("color.dividerNormal"))     { theme.dividerNormalColor = c }
        if let c = Color(hex: ud("color.dividerActive"))     { theme.dividerActiveColor = c }
        if let c = Color(hex: ud("color.panelBorderActive"))   { theme.panelBorderActive = c }
        if let c = Color(hex: ud("color.panelBorderInactive")) { theme.panelBorderInactive = c }
        let bw = udD("panel.borderWidth")
        if bw > 0 { theme.panelBorderWidth = CGFloat(bw) }
        if let c = Color(hex: ud("color.warmWhite"))         { theme.warmWhite = c }
        if let c = Color(hex: ud("color.zebraActiveEven"))   { theme.zebraActiveEven = c }
        if let c = Color(hex: ud("color.zebraActiveOdd"))    { theme.zebraActiveOdd = c }
        if let c = Color(hex: ud("color.zebraInactiveEven")) { theme.zebraInactiveEven = c }
        if let c = Color(hex: ud("color.zebraInactiveOdd"))  { theme.zebraInactiveOdd = c }
        if let c = Color(hex: ud("color.filterActive"))      { theme.filterActiveColor = c }
        // BreadCrumb
        if let c = Color(hex: ud("color.breadcrumbTextActive"))   { theme.breadcrumbTextActive = c }
        if let c = Color(hex: ud("color.breadcrumbTextInactive")) { theme.breadcrumbTextInactive = c }
        if let c = Color(hex: ud("color.breadcrumbBgActive"))     { theme.breadcrumbBgActive = c }
        if let c = Color(hex: ud("color.breadcrumbBgInactive"))   { theme.breadcrumbBgInactive = c }
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
            "color.dividerNormal", "color.dividerActive", "color.panelBorderActive", "color.panelBorderInactive",
            "color.warmWhite", "color.zebraActiveEven", "color.zebraActiveOdd",
            "color.zebraInactiveEven", "color.zebraInactiveOdd", "color.filterActive",
            "color.breadcrumbTextActive", "color.breadcrumbTextInactive",
            "color.breadcrumbBgActive", "color.breadcrumbBgInactive"
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
        hexDividerNormal = ""; hexDividerActive = ""
        hexPanelBorderActive = ""; hexPanelBorderInactive = ""
        storedPanelBorderWidth = 0
        hexWarmWhite = ""
        hexZebraActiveEven = ""; hexZebraActiveOdd = ""
        hexZebraInactiveEven = ""; hexZebraInactiveOdd = ""
        hexFilterActive = ""
        hexBreadcrumbTextActive = ""; hexBreadcrumbTextInactive = ""
        hexBreadcrumbBgActive = "";   hexBreadcrumbBgInactive = ""
        breadcrumbFontSize = 0
        loadTheme(id: theme.id)
    }
}

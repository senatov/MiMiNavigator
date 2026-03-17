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

    private init() {
        loadTheme(id: savedThemeID)
    }

    func loadTheme(id: String) {
        let base = ColorTheme.allPresets.first { $0.id == id } ?? .defaultTheme
        savedThemeID = base.id
        // Apply custom hex overrides on top of preset
        activeTheme = applyOverrides(to: base)
        log.info("[ColorTheme] loaded '\(base.name)' with \(countOverrides()) custom override(s)")
    }
    // MARK: - Apply hex overrides to base theme
    private func applyOverrides(to base: ColorTheme) -> ColorTheme {
        var theme = base
        if let c = Color(hex: hexPanelBg)    { theme.panelBackground = c }
        if let c = Color(hex: hexPanelText)  { theme.panelText = c }
        if let c = Color(hex: hexDirName)    { theme.dirNameColor = c }
        if let c = Color(hex: hexFileName)   { theme.fileNameColor = c }
        if let c = Color(hex: hexSymlink)    { theme.symlinkColor = c }
        if let c = Color(hex: hexSelActive)  { theme.selectionActive = c }
        if let c = Color(hex: hexSelInactive) { theme.selectionInactive = c }
        if let c = Color(hex: hexSelBorder)  { theme.selectionBorder = c }
        theme.selectionLineWidth = CGFloat(storedLineWidth)
        if let c = Color(hex: hexSeparator)  { theme.separatorColor = c }
        if let c = Color(hex: hexDialogBase) { theme.dialogBase = c }
        if let c = Color(hex: hexDialogStripe) { theme.dialogStripe = c }
        if let c = Color(hex: hexAccent)     { theme.accentColor = c }
        if let c = Color(hex: hexDialogBackground) { theme.dialogBackground = c }
        // Extended tokens
        if let c = Color(hex: hexHiddenFile)       { theme.hiddenFileColor = c }
        if let c = Color(hex: hexMarkedFile)       { theme.markedFileColor = c }
        if let c = Color(hex: hexParentEntry)      { theme.parentEntryColor = c }
        if let c = Color(hex: hexArchivePath)      { theme.archivePathColor = c }
        if let c = Color(hex: hexMarkedCount)      { theme.markedCountColor = c }
        if let c = Color(hex: hexColumnName)       { theme.columnNameColor = c }
        if let c = Color(hex: hexColumnSize)       { theme.columnSizeColor = c }
        if let c = Color(hex: hexColumnKind)       { theme.columnKindColor = c }
        if let c = Color(hex: hexColumnDate)       { theme.columnDateColor = c }
        if let c = Color(hex: hexColumnPermissions) { theme.columnPermissionsColor = c }
        if let c = Color(hex: hexColumnOwner)       { theme.columnOwnerColor = c }
        if let c = Color(hex: hexColumnGroup)       { theme.columnGroupColor = c }
        if let c = Color(hex: hexColumnChildCount)  { theme.columnChildCountColor = c }
        if let c = Color(hex: hexDividerNormal)    { theme.dividerNormalColor = c }
        if let c = Color(hex: hexDividerActive)    { theme.dividerActiveColor = c }
        if let c = Color(hex: hexPanelBorderActive)   { theme.panelBorderActive = c }
        if let c = Color(hex: hexPanelBorderInactive) { theme.panelBorderInactive = c }
        if storedPanelBorderWidth > 0 { theme.panelBorderWidth = CGFloat(storedPanelBorderWidth) }
        if let c = Color(hex: hexWarmWhite)        { theme.warmWhite = c }
        if let c = Color(hex: hexZebraActiveEven)   { theme.zebraActiveEven = c }
        if let c = Color(hex: hexZebraActiveOdd)    { theme.zebraActiveOdd = c }
        if let c = Color(hex: hexZebraInactiveEven) { theme.zebraInactiveEven = c }
        if let c = Color(hex: hexZebraInactiveOdd)  { theme.zebraInactiveOdd = c }
        if let c = Color(hex: hexFilterActive)     { theme.filterActiveColor = c }
        // BreadCrumb
        if let c = Color(hex: hexBreadcrumbTextActive)   { theme.breadcrumbTextActive = c }
        if let c = Color(hex: hexBreadcrumbTextInactive) { theme.breadcrumbTextInactive = c }
        if let c = Color(hex: hexBreadcrumbBgActive)     { theme.breadcrumbBgActive = c }
        if let c = Color(hex: hexBreadcrumbBgInactive)   { theme.breadcrumbBgInactive = c }
        if breadcrumbFontSize > 0 { theme.breadcrumbFontSize = CGFloat(breadcrumbFontSize) }
        return theme
    }
    // MARK: - Count active overrides
    private func countOverrides() -> Int {
        [hexPanelBg, hexPanelText, hexDirName, hexFileName, hexSymlink,
         hexSelActive, hexSelInactive, hexSelBorder, hexSeparator,
         hexDialogBase, hexDialogStripe, hexAccent, hexDialogBackground,
         hexHiddenFile, hexMarkedFile, hexParentEntry, hexArchivePath, hexMarkedCount,
         hexColumnName, hexColumnSize, hexColumnKind, hexColumnDate,
         hexColumnPermissions, hexColumnOwner, hexColumnGroup, hexColumnChildCount,
         hexDividerNormal, hexDividerActive, hexPanelBorderActive, hexPanelBorderInactive,
         hexWarmWhite, hexZebraActiveEven, hexZebraActiveOdd,
         hexZebraInactiveEven, hexZebraInactiveOdd, hexFilterActive,
         hexBreadcrumbTextActive, hexBreadcrumbTextInactive,
         hexBreadcrumbBgActive, hexBreadcrumbBgInactive]
            .filter { !$0.isEmpty }.count
    }

    // MARK: - Reload overrides on top of current preset
    func reloadOverrides() {
        let base = ColorTheme.allPresets.first { $0.id == savedThemeID } ?? .defaultTheme
        activeTheme = applyOverrides(to: base)
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

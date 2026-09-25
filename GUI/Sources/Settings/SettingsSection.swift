// SettingsSection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enum of all Settings sections — sidebar navigation model.
//   Colors is split into sub-sections (Xcode/Nova style): each maps to a
//   focused pane so the right side never exceeds one screen height.

import Foundation

// MARK: - SettingsSection
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general        = "General"
    // Colors group
    case colorsPanels   = "Panels & Files"
    case colorsChrome   = "Chrome & Borders"
    case colorsBreadcrumb = "BreadCrumb"
    case colorsButtons  = "Buttons"
    case colorsInputFields = "Input Fields"
    // Other
    case panels         = "Panels"
    case preview        = "Preview"
    case tabs           = "Tabs"
    case archives       = "Archives"
    case network        = "Network"
    case cloudLink      = "Cloud Share+Link"
    case diffTool       = "Diff Tool"
    case progress       = "Progress Panel"
    case externalTools  = "External Tools"
    case permissions    = "Permissions"
    case hotkeys        = "Hotkeys"

    var id: String { rawValue }

    /// Display label shown in sidebar
    var label: String { rawValue }

    /// Optional group header — sidebar renders a divider + group label above first item in group
    var groupHeader: String? {
        switch self {
        case .colorsPanels:   return "Colors"
        case .panels:         return "Layout"
        case .cloudLink:      return "Services"
        default:              return nil
        }
    }

    /// Indent level — color sub-sections are indented under "Colors" header
    var isSubItem: Bool {
        switch self {
        case .colorsPanels, .colorsChrome, .colorsBreadcrumb, .colorsButtons, .colorsInputFields: return true
        default: return false
        }
    }

    var icon: String {
        switch self {
        case .general:           return "gear"
        case .colorsPanels:      return "rectangle.split.2x1.fill"
        case .colorsChrome:      return "slider.horizontal.3"
        case .colorsBreadcrumb:  return "text.alignleft"
        case .colorsButtons:     return "button.programmable"
        case .colorsInputFields: return "character.cursor.ibeam"
        case .panels:            return "rectangle.split.2x1"
        case .preview:           return "rectangle.trailinghalf.inset.filled"
        case .tabs:              return "rectangle.on.rectangle"
        case .archives:          return "archivebox"
        case .network:           return "network"
        case .cloudLink:         return "link.badge.plus"
        case .diffTool:          return "arrow.left.arrow.right"
        case .progress:          return "chart.bar.doc.horizontal"
        case .externalTools:     return "wrench.and.screwdriver"
        case .permissions:       return "lock.shield"
        case .hotkeys:           return "keyboard"
        }
    }

    var summary: String {
        switch self {
        case .general: return "Appearance, language, file display and startup behavior"
        case .colorsPanels: return "File panels, rows, metadata and selection colors"
        case .colorsChrome: return "Window chrome, separators and structural surfaces"
        case .colorsBreadcrumb: return "Path navigation, segments and interaction states"
        case .colorsButtons: return "Toolbar and command button appearance"
        case .colorsInputFields: return "Dialog placeholders and field-label appearance"
        case .panels: return "Panel layout, columns and file presentation"
        case .preview: return "Embedded preview modes and remembered file-type rules"
        case .tabs: return "Tab behavior, font, colors and corner shape"
        case .archives: return "Archive formats, extraction and compression"
        case .network: return "Network discovery and remote connection behavior"
        case .cloudLink: return "Cloud providers, sharing and shortened links"
        case .diffTool: return "Comparison tools, paths and launch behavior"
        case .progress: return "Operation progress window appearance and behavior"
        case .externalTools: return "Command-line dependencies and diagnostics"
        case .permissions: return "Protected locations and authorized folders"
        case .hotkeys: return "Keyboard shortcuts, presets and conflict management"
        }
    }

    // MARK: - Settings Search Index
    var searchableText: String {
        [label, summary, searchTerms].joined(separator: " ")
    }

    private var searchTerms: String {
        switch self {
        case .general:
            return "appearance light dark language toolbar graphs memory threads intervals interface scale font icon size hidden files extensions auto-fit columns startup home last visited desktop downloads"
        case .colorsPanels:
            return "theme preset dark variant background file name directory symlink accent dialog selection active inactive border hidden marked parent archive path count column name size kind date permissions owner group divider line width"
        case .colorsChrome:
            return "command bars moire panel divider border focused unfocused width table background warm white zebra stripes active inactive filter highlight top menu bottom action bar"
        case .colorsBreadcrumb:
            return "path text active inactive environment variable hover hovered segment background border typography font size italic preview"
        case .colorsButtons:
            return "button border color width corner radius shadow color radius offset preview"
        case .colorsInputFields:
            return "dialog input field placeholder hint intensity opacity label dark blue rounded text"
        case .panels:
            return "row height compact normal relaxed spacious hidden files extensions icons show file folder calculate sizes active highlight sorting ascending descending folders first date format short medium relative iso size display kilobytes open single double click"
        case .preview:
            return "automatic known text image pdf media document archive executable unknown extension file type quick look binary remembered rules"
        case .tabs:
            return "restore tabs launch close button maximum max open tabs font size text background color active inactive panel dim opacity corner radius preview"
        case .archives:
            return "archive tools format zip tar gzip bzip xz compression level extract subfolder progress password encrypted keychain open browse default app repack confirm auto 7zip rar install"
        case .network:
            return "timeout retry reconnect fing discovery local api port key password keychain sidebar connected servers"
        case .cloudLink:
            return "google client secret refresh token dropbox oauth tinyurl api token credentials save reload clear reveal keychain"
        case .diffTool:
            return "compare active tool auto kdiff3 beyond compare custom application binary arguments left right priority installed path scope"
        case .progress:
            return "background border text title status log font size panel width height auto-close operation saved frames positions reset defaults"
        case .externalTools:
            return "command line dependencies diagnostics install path status ffmpeg seven zip 7z tools"
        case .permissions:
            return "full disk access macos desktop documents icloud removable volumes protected data authorized folders bookmarks add remove"
        case .hotkeys:
            return "keyboard shortcuts keys preset conflict commands bindings reset"
        }
    }
}

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
    // Other
    case panels         = "Panels"
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
        case .colorsPanels, .colorsChrome, .colorsBreadcrumb, .colorsButtons: return true
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
        case .panels:            return "rectangle.split.2x1"
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
        case .panels: return "Panel layout, columns and file presentation"
        case .tabs: return "Tab behavior, sizing and navigation"
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
}

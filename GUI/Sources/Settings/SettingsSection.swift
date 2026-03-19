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
    case diffTool       = "Diff Tool"
    case progress       = "Progress Panel"
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
        case .diffTool:          return "arrow.left.arrow.right"
        case .progress:          return "chart.bar.doc.horizontal"
        case .permissions:       return "lock.shield"
        case .hotkeys:           return "keyboard"
        }
    }
}

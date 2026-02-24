// ToolbarItemID.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumeration of all customisable toolbar buttons.
//   Provides metadata (label, SF symbol, help text) used by both
//   the live toolbar and the Customize Toolbar dialog.

import Foundation

// MARK: - Toolbar Item Identifier
/// Every button slot that can appear in the top toolbar.
/// Raw value is the stable persistence key stored in UserDefaults.
enum ToolbarItemID: String, CaseIterable, Identifiable, Codable, Sendable {

    case refresh        = "refresh"
    case hiddenFiles    = "hiddenFiles"
    case openWith       = "openWith"
    case swapPanels     = "swapPanels"
    case compare        = "compare"
    case network        = "network"
    case connectServer  = "connectServer"
    case findFiles      = "findFiles"

    var id: String { rawValue }

    // MARK: - Display metadata

    /// Short label shown below icon in the dialog palette.
    var label: String {
        switch self {
        case .refresh:       return "Refresh"
        case .hiddenFiles:   return "Hidden Files"
        case .openWith:      return "Open With"
        case .swapPanels:    return "Swap Panels"
        case .compare:       return "Compare"
        case .network:       return "Network"
        case .connectServer: return "Connect"
        case .findFiles:     return "Find Files"
        }
    }

    /// SF Symbol name for the button icon.
    var systemImage: String {
        switch self {
        case .refresh:       return "arrow.triangle.2.circlepath"
        case .hiddenFiles:   return "eye.slash"
        case .openWith:      return "arrow.up.forward.app"
        case .swapPanels:    return "arrow.left.arrow.right"
        case .compare:       return "doc.text.magnifyingglass"
        case .network:       return "network"
        case .connectServer: return "server.rack"
        case .findFiles:     return "magnifyingglass"
        }
    }

    /// Tooltip / help text used in the palette.
    var helpText: String {
        switch self {
        case .refresh:       return "Refresh file lists (⌘R)"
        case .hiddenFiles:   return "Show / hide hidden files (⌘.)"
        case .openWith:      return "Open selected file or Get Info (⌘O)"
        case .swapPanels:    return "Swap left and right panel directories"
        case .compare:       return "Compare items via FileMerge / DiffMerge"
        case .network:       return "Network Neighborhood (⌘N)"
        case .connectServer: return "Connect to Server (⌃N)"
        case .findFiles:     return "Find Files (⇧⌘F)"
        }
    }

    // MARK: - Factory default order (all visible, in this order)
    static let defaultOrder: [ToolbarItemID] = [
        .refresh,
        .hiddenFiles,
        .openWith,
        .swapPanels,
        .compare,
        .network,
        .connectServer,
        .findFiles,
    ]
}

// SettingsSection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enum of all Settings sections — sidebar navigation model.

import Foundation

// MARK: - SettingsSection
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general     = "General"
    case colors      = "Colors"
    case panels      = "Panels"
    case tabs        = "Tabs"
    case archives    = "Archives"
    case network     = "Network"
    case diffTool    = "Diff Tool"
    case permissions = "Permissions"
    case hotkeys     = "Hotkeys"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:     return "gear"
        case .colors:      return "paintpalette"
        case .panels:      return "rectangle.split.2x1"
        case .tabs:        return "rectangle.on.rectangle"
        case .archives:    return "archivebox"
        case .network:     return "network"
        case .diffTool:    return "arrow.left.arrow.right"
        case .permissions: return "lock.shield"
        case .hotkeys:     return "keyboard"
        }
    }
}

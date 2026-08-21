// ColumnLayoutPreset.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Professional column presets for common file-management workflows.

import Foundation

// MARK: - Column Layout Preset
enum ColumnLayoutPreset: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case detailed = "Detailed"
    case developer = "Developer"
    case allMetadata = "All Metadata"

    var id: String { rawValue }

    var columns: [ColumnID] {
        switch self {
        case .compact:
            return [.name, .dateModified, .size, .kind]
        case .detailed:
            return [.name, .dateModified, .size, .kind, .owner, .childCount]
        case .developer:
            return [.name, .dateModified, .size, .kind, .permissions, .owner, .group]
        case .allMetadata:
            return ColumnLayoutModel.defaultOrder
        }
    }

    var systemImage: String {
        switch self {
        case .compact: return "rectangle.compress.vertical"
        case .detailed: return "list.bullet.rectangle"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .allMetadata: return "tablecells"
        }
    }
}

// PanelSide.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Enum representing left or right panel in dual-pane file manager

import Foundation

// MARK: - Panel Side
/// Identifies which panel (left or right) in the dual-pane interface
enum PanelSide: String, Codable, Sendable, CaseIterable {
    case left
    case right
    
    /// Returns the opposite panel side
    var opposite: PanelSide {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

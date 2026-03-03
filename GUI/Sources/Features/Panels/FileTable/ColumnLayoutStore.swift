// ColumnLayoutStore.swift
// MiMiNavigator
//
// Created by Claude on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton store for ColumnLayoutModel instances.
//              Prevents recreating ColumnLayoutModel on every SwiftUI view rebuild.

import SwiftUI
import FileModelKit

// MARK: - Column Layout Store (Singleton)
/// Holds ColumnLayoutModel instances for left and right panels.
/// Using a singleton prevents expensive UserDefaults I/O on every view rebuild.
@MainActor
final class ColumnLayoutStore {
    static let shared = ColumnLayoutStore()
    
    let left: ColumnLayoutModel
    let right: ColumnLayoutModel
    
    private init() {
        left = ColumnLayoutModel(panelSide: .left)
        right = ColumnLayoutModel(panelSide: .right)
    }
    
    func layout(for side: PanelSide) -> ColumnLayoutModel {
        switch side {
        case .left: return left
        case .right: return right
        }
    }
}

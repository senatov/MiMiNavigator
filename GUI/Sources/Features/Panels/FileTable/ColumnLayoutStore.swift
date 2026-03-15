// ColumnLayoutStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton store holding column layouts for both panels.
//              Loaded ONCE at startup.

import FileModelKit
import SwiftUI

// MARK: - ColumnLayoutStore
@MainActor
@Observable
final class ColumnLayoutStore {
    static let shared = ColumnLayoutStore()

    private(set) var left: ColumnLayoutModel
    private(set) var right: ColumnLayoutModel

    private init() {
        self.left = ColumnLayoutModel(panelSide: .left)
        log.debug("[ColumnLayoutStore] left layout created")
        self.right = ColumnLayoutModel(panelSide: .right)
        log.debug("[ColumnLayoutStore] right layout created")
        log.info("[ColumnLayoutStore] initialized — layouts loaded once")
    }

    func layout(for side: PanelSide) -> ColumnLayoutModel {
        side == .left ? left : right
    }
}

// BreadCrumbMnu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Navigation menu components for breadcrumb panel

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Favorites Button Section (left side of breadcrumb)
struct BreadCrumbMnu: View {
    @Environment(AppState.self) var appState
    let panelSide: FavPanelSide

    init(selectedSide: FavPanelSide) {
        self.panelSide = selectedSide
    }

    var body: some View {
        HStack(spacing: 4) {
            BreadCrumbToolBar(selectedSide: panelSide)
        }
        .padding(.leading, 6)
    }
}

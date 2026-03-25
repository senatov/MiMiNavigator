// AppKitDropView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit drop target overlay — receives drops from EXTERNAL apps (Finder, etc.)
// Internal panel-to-panel drops are handled by DragNSView directly.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - AppKitDropView
struct AppKitDropView: NSViewRepresentable {
    let panelSide: FavPanelSide
    let appState: AppState
    let dragDropManager: DragDropManager

    func makeNSView(context: Context) -> DropNSView {
        let view = DropNSView()
        view.panelSide = panelSide
        view.appState = appState
        view.dragDropManager = dragDropManager
        return view
    }

    func updateNSView(_ nsView: DropNSView, context: Context) {
        nsView.panelSide = panelSide
        nsView.appState = appState
        nsView.dragDropManager = dragDropManager
    }
}

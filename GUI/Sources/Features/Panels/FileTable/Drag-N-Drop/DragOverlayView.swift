// DragOverlayView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 16.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSViewRepresentable wrapper for DragNSView (AppKit drag source)

import AppKit
import FileModelKit
import SwiftUI


// MARK: - DragOverlayView
struct DragOverlayView: NSViewRepresentable {
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    let panelSide: FavPanelSide


    func makeNSView(context: Context) -> DragNSView {
        let view = DragNSView(appState: appState)
        view.panelSide = panelSide
        view.dragDropManager = dragDropManager
        return view
    }


    func updateNSView(_ nsView: DragNSView, context: Context) {
        nsView.panelSide = panelSide
        nsView.dragDropManager = dragDropManager
    }
}

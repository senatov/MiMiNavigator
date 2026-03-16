//
//  DragOverlayView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


    import AppKit
    import FileModelKit
    import SwiftUI

    struct DragOverlayView: NSViewRepresentable {
        @Environment(AppState.self) var appState
        @Environment(DragDropManager.self) var dragDropManager

        let panelSide: PanelSide

        func makeNSView(context: Context) -> DragNSView {
            let view = DragNSView()
            view.panelSide = panelSide
            view.dragDropManager = dragDropManager
            view.appState = appState
            return view
        }

        func updateNSView(_ nsView: DragNSView, context: Context) {
            nsView.panelSide = panelSide
            nsView.dragDropManager = dragDropManager
            nsView.appState = appState
        }
    }

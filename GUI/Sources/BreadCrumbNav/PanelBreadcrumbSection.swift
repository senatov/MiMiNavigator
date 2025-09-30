//
//  PanelBreadcrumbSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import AppKit
import SwiftUI

// MARK: - Subviews
struct PanelBreadcrumbSection: View {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide
    let currentPath: URL?
    let onPathChange: (URL?) -> Void

    var body: some View {
        log.info(#function + " for side \(panelSide) with current path: \(currentPath?.path ?? "nil")")
        return BreadCrumbControlWrapper(selectedSide: panelSide)
            .onChange(of: currentPath, initial: false) { _, newValue in
                onPathChange(newValue)
            }
            .task { @MainActor in
                appState.focusedPanel = panelSide
            }
    }
}

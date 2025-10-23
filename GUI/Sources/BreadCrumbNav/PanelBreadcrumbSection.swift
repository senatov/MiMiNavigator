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
    let currentPath: URL?
    let onPathChange: (URL?) -> Void

    // MARK: -
    var body: some View {
        log.debug(#function + " — focusedPanel=\(appState.focusedPanel), currentPath=\(currentPath?.path ?? "nil")")  // SwiftBeaver: debug level
        return BreadCrumbControlWrapper(selectedSide: appState.focusedPanel)
            .environmentObject(appState)
            .onChange(of: currentPath, initial: false) { _, newValue in
                onPathChange(newValue)
            }
    }
}

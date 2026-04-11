//
//  FileTableView+AutoFit.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Thin bridge — delegates autofit to AutoFitScheduler singleton.

import Foundation

extension FileTableView {

    /// Triggers navigation autofit via centralized scheduler.
    func scheduleAutoFitIfNeeded() {
        AutoFitScheduler.shared.scheduleNavigationFit(
            panel: panelSide, appState: appState)
    }


    /// Triggers resize autofit via centralized scheduler.
    func handleContainerWidthChange(_ newWidth: CGFloat) {
        AutoFitScheduler.shared.handleResize(
            panel: panelSide, newWidth: newWidth, appState: appState)
    }
}

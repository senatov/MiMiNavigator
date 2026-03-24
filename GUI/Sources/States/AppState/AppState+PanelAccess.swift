//
//  AppState+Refresh2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation

// MARK: - Panel Access
extension AppState {

    func panel(_ side: PanelSide) -> PanelState {
        side == .left ? leftPanel : rightPanel
    }

    subscript(panel side: PanelSide) -> PanelState {
        get { side == .left ? leftPanel : rightPanel }
        set {
            if side == .left { leftPanel = newValue } else { rightPanel = newValue }
        }
    }

    /// Unified panel update helper (keeps mutation localized and consistent)
    func updatePanel(_ side: PanelSide, update: (PanelState) -> Void) {
        switch side {
            case .left:
                update(leftPanel)
            case .right:
                update(rightPanel)
        }
    }
}

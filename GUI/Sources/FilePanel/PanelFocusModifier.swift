//
// PanelFocusModifier.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - PanelFocusModifier

struct PanelFocusModifier: ViewModifier {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    let onFocusLost: () -> Void

    // MARK: - -
    func body(content: Content) -> some View {
        // Log removed - called too frequently
        return
            content
            .onChange(of: appState.focusedPanel, initial: false) { oldValue, newValue in
                // When focus moves away from this panel, trigger the onFocusLost callback
                if newValue != panelSide && oldValue == panelSide {
                    log.info("Focus moved from \(oldValue) to \(newValue); calling onFocusLost on <<\(panelSide)>>")
                    onFocusLost()
                }
            }
    }
}

extension View {
    // MARK: - Applies focus behavior for a file panel; sets focus on tap and clears selection when losing focus.
    func panelFocus(panelSide: PanelSide, onFocusLost: @escaping () -> Void) -> some View {
        // Log removed - extension called frequently
        return modifier(PanelFocusModifier(panelSide: panelSide, onFocusLost: onFocusLost))
    }
}

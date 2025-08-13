//
//  PanelFocusModifier.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - PanelFocusModifier

struct PanelFocusModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide
    let onFocusLost: () -> Void

    // MARK: - -
    func body(content: Content) -> some View {
        log.info(#function + " for panel side: \(panelSide)")
        return content
            .contentShape(Rectangle())
            .onTapGesture {
                // Set focus to this panel when the user interacts with it
                log.debug("Panel tapped, focus -> \(panelSide)")
                appState.focusedPanel = panelSide
            }
            .onChange(of: appState.focusedPanel, initial: false) { oldValue, newValue in
                // When focus moves away from this panel, clear selection here
                if newValue != panelSide {
                    log.debug("Focus moved from \(oldValue) to \(newValue); clearing selection on \(panelSide)")
                    onFocusLost()
                }
            }
    }
}

extension View {
    // MARK: - Applies focus behavior for a file panel; sets focus on tap and clears selection when losing focus.
    func panelFocus(panelSide: PanelSide, onFocusLost: @escaping () -> Void) -> some View {
        log.info(#function + " for panel side: \(panelSide)")
        return modifier(PanelFocusModifier(panelSide: panelSide, onFocusLost: onFocusLost))
    }
}

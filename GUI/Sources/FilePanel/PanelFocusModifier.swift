//
//  PanelFocusModifier.swift
//  MiMiNavigator
//
//  Clean focus observer: does NOT set focus itself; only reacts to focus loss.
//  Swift 6.2 / macOS 15.4+. Comments in English only.
//

import AppKit
import SwiftUI

// MARK: - PanelFocusModifier

struct PanelFocusModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide
    let onFocusLost: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            // React only when focus moves AWAY from this panel
            .onChange(of: appState.focusedPanel) { oldValue, newValue in
                log.info("PanelFocusModifier.onChange: \(oldValue) → \(newValue) for side=\(panelSide)")
                if oldValue == panelSide && newValue != panelSide {
                    log.info("Focus moved from this panel (\(panelSide)) to \(newValue); invoking onFocusLost()")
                    onFocusLost()
                }
            }
    }
}

extension View {
    /// Applies focus behavior for a file panel; **does not** set focus.
    /// It only reports when the panel loses focus so the caller can react (e.g., hide popups).
    func panelFocus(panelSide: PanelSide, onFocusLost: @escaping () -> Void) -> some View {
        log.info(#function + " for panel side: \(panelSide)")
        return modifier(PanelFocusModifier(panelSide: panelSide, onFocusLost: onFocusLost))
    }
}

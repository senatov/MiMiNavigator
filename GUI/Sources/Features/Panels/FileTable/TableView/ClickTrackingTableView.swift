// ClickTrackingTableView.swift
// MiMiNavigator
//
// Created by Claude on 25.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSTableView subclass — captures mouse modifiers + clears marks on empty-area click

import AppKit
import FileModelKit
import LogKit

// MARK: - Click Tracking Table View
/// Captures modifier flags from mouse events so Coordinator can distinguish
/// plain clicks (clear marks) from Cmd/Shift clicks (extend selection).
/// Also handles click on empty area below file rows — NSTableView won't fire
/// tableViewSelectionDidChange if selection doesn't actually change.
final class ClickTrackingTableView: NSTableView {

    /// Modifier flags from the most recent mouseDown — read by Coordinator in tableViewSelectionDidChange
    var lastMouseDownModifiers: NSEvent.ModifierFlags = []

    override func mouseDown(with event: NSEvent) {
        lastMouseDownModifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])

        // detect click on empty area below last row
        let loc = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: loc)
        let isPlain = lastMouseDownModifiers.isEmpty || lastMouseDownModifiers == .capsLock

        if clickedRow == -1 && isPlain {
            // empty area click → nuke all marks on this panel
            let side = panelSideFromPosition()
            AppStateProvider.shared?.unmarkAll(on: side)
            log.debug("[ClickTrackingTV] empty area click → marks nuked on \(side)")
        }

        super.mouseDown(with: event)
    }

    /// Determine panel side by checking horizontal position in window
    private func panelSideFromPosition() -> FavPanelSide {
        guard let window else { return .left }
        let frameInWindow = convert(bounds, to: nil)
        let midX = frameInWindow.midX
        return midX < window.frame.width / 2 ? .left : .right
    }
}

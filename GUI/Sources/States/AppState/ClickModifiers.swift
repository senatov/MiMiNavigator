// ClickModifiers.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Click modifier keys for Finder-style multi-selection

import AppKit
import FileModelKit
import Foundation

// MARK: - Click Modifiers
/// Represents modifier keys held during a mouse click
enum ClickModifiers: Sendable {
    /// No modifier keys — plain click (select single, clear marks)
    case none
    /// Cmd key held — toggle mark on clicked file
    case command
    /// Shift key held — range select from anchor to clicked file
    case shift
}

// MARK: - Panel Click Modifier Capture
@MainActor
enum PanelClickModifierCapture {
    private static var lastClick: [FavPanelSide: (modifiers: ClickModifiers, time: Date)] = [:]

    static func record(_ flags: NSEvent.ModifierFlags, for panel: FavPanelSide) {
        let modifiers: ClickModifiers
        if flags.contains(.command) {
            modifiers = .command
        } else if flags.contains(.shift) {
            modifiers = .shift
        } else {
            modifiers = .none
        }
        lastClick[panel] = (modifiers, Date())
    }

    static func modifiers(for panel: FavPanelSide) -> ClickModifiers {
        guard let click = lastClick[panel], Date().timeIntervalSince(click.time) < 1 else { return .none }
        return click.modifiers
    }
}

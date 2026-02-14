// ClickModifiers.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Click modifier keys for Finder-style multi-selection

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

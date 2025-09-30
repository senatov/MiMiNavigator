//
//  AppState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// Existing code...

func togglePanel() {
    log.debug("TAB - Focused panel toggled")
    // existing implementation...
}

// MARK: - Toggle focus with optional Shift handling (API-compatible overload)
func togglePanel(shift: Bool) {
    // English comment: With two panels, Shift-Tab behavior is identical.
    // Keep this overload so commands can pass a boolean without branching here.
    togglePanel()
}

// Existing code...

func selectionCopy() {
    // existing copy implementation...
}

// MARK: - API compatibility wrapper (keeps previous naming used by commands)
func copySelected() {
    selectionCopy()
}

// Existing code...

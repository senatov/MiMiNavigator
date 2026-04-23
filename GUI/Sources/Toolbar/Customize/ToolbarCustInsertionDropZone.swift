// ToolbarCustInsertionDropZone.swift
// MiMiNavigator
//
// Created by Codex on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

struct ToolbarCustInsertionDropZone: View {
    let isActive: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(isActive ? DialogColors.accent.opacity(0.95) : DialogColors.border.opacity(0.18))
            .frame(width: isActive ? 8 : 4, height: 52)
            .opacity(isActive ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

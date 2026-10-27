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
            .fill(isActive ? DialogColors.accent : Color.clear)
            .frame(width: 4, height: 42)
            .frame(width: 10, height: 58)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

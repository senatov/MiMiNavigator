// ToolbarCustInsertionDropZone.swift
// MiMiNavigator
//
// Created by Codex on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

struct ToolbarCustInsertionDropZone: View {
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isActive ? Color.accentColor : Color.clear)
            .frame(width: isActive ? 6 : 10, height: 42)
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

// HIGDialogStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Consistent panel styling for all modal dialogs.

import SwiftUI

// MARK: - HIGDialogStyle
/// Uses Word-Einstellungen gray palette: base #EFEFEF background, 12pt radius.
struct HIGDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .frame(minWidth: 320, maxWidth: 440)
            .background(DialogColors.base)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

// MARK: - View Extension
extension View {
    func higDialogStyle() -> some View {
        modifier(HIGDialogStyle())
    }
}

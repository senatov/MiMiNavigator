// HIGDialogStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Consistent panel styling for all modal dialogs.

import AppKit
import SwiftUI

// MARK: - Dialog Window Metrics
@MainActor
enum DialogWindowMetrics {
    private static let fallbackSize = NSSize(width: 1_248, height: 768)

    // MARK: - Maximum Size
    static var maximumSize: NSSize {
        let host = NSApp.mainWindow?.sheetParent ?? NSApp.mainWindow
        let screen = host?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame.size ?? fallbackSize
        let available = host?.contentLayoutRect.size ?? visible
        return NSSize(width: min(visible.width, available.width) - 24,
                      height: min(visible.height, available.height) - 24)
    }
}

// MARK: - HIGDialogStyle
/// Uses Word-Einstellungen gray palette: base #EFEFEF background, 12pt radius.
struct HIGDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        let maximumSize = DialogWindowMetrics.maximumSize
        let dialogWidth = min(DesignTokens.Dialog.standardWidth, maximumSize.width)
        content
            .keyboardFocusSection()
            .padding(DesignTokens.Dialog.contentPadding)
            .frame(width: dialogWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(DialogColors.base)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.dialog, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.dialog, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Stable Dialog Window Surface
/// Opaque dialog surface for standalone windows and sheets. Unlike a root
/// glass effect, this never expands beyond the window or intercepts controls.
struct DialogWindowSurface: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(DialogColors.base)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - View Extension
extension View {
    func higDialogStyle() -> some View {
        modifier(HIGDialogStyle())
    }
    func dialogWindowSurface(cornerRadius: CGFloat) -> some View {
        modifier(DialogWindowSurface(cornerRadius: cornerRadius))
    }
}

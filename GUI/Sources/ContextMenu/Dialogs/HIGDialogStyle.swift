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
    private static let fallbackSize = NSSize(width: 1_200, height: 700)

    static var maximumSize: NSSize {
        let size = hostWindow?.contentLayoutRect.size ?? fallbackSize
        return NSSize(width: size.width * 0.75, height: size.height * 0.75)
    }

    private static var hostWindow: NSWindow? {
        NSApp.windows.first {
            !($0 is NSPanel) && $0.isVisible && $0.styleMask.contains(.titled)
        }
    }
}

// MARK: - HIGDialogStyle
/// Uses Word-Einstellungen gray palette: base #EFEFEF background, 12pt radius.
struct HIGDialogStyle: ViewModifier {
    func body(content: Content) -> some View {
        let maximumSize = DialogWindowMetrics.maximumSize
        content
            .keyboardFocusSection()
            .forcedDialogTabNavigation()
            .padding(24)
            .fixedSize(horizontal: true, vertical: false)
            .frame(
                minWidth: min(320, maximumSize.width),
                idealWidth: min(440, maximumSize.width),
                maxWidth: maximumSize.width,
                maxHeight: maximumSize.height
            )
            .background(DialogColors.base)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(0.75), lineWidth: 1)
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

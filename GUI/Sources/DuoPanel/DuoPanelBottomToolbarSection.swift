//
// DuoPanelBottomToolbarSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Bottom toolbar with action buttons
struct DuoPanelBottomToolbarSection: View {
    let onView: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    let onNewFolder: () -> Void
    let onDelete: () -> Void
    let onSettings: () -> Void
    let onConsole: () -> Void
    let onExit: () -> Void
    
    private enum Layout {
        static let toolbarHorizontalPadding: CGFloat = 16
        static let toolbarVerticalPadding: CGFloat = 12
        static let toolbarCornerRadius: CGFloat = 10
        static let toolbarOuterPadding: CGFloat = 8
        static let toolbarBottomPadding: CGFloat = 8
        static let toolbarButtonSpacing: CGFloat = 12
    }
    
    var body: some View {
        HStack(spacing: Layout.toolbarButtonSpacing) {
            makeButton(title: "F3 View", icon: "eye.circle", action: onView)
            makeButton(title: "F4 Edit", icon: "pencil", action: onEdit)
            makeButton(title: "F5 Copy", icon: "doc.on.doc", action: onCopy)
            makeButton(title: "F6 Move", icon: "square.and.arrow.down.on.square", action: onMove)
            makeButton(title: "F7 NewFolder", icon: "folder.badge.plus", action: onNewFolder)
            makeButton(title: "F8 Delete", icon: "minus.rectangle", action: onDelete)
            makeButton(title: "Settings", icon: "gearshape", action: onSettings)
            makeButton(title: "Console", icon: "terminal", action: onConsole)
            makeButton(title: "Exit", icon: "power", action: onExit)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.toolbarHorizontalPadding)
        .padding(.vertical, Layout.toolbarVerticalPadding)
        .background(
            DuoPanelToolbarBackground(cornerRadius: Layout.toolbarCornerRadius)
        )
        .padding(.horizontal, Layout.toolbarOuterPadding)
        .padding(.bottom, Layout.toolbarBottomPadding)
    }
    
    private func makeButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        DownToolbarButtonView(
            title: title,
            systemImage: icon,
            action: action
        )
    }
}

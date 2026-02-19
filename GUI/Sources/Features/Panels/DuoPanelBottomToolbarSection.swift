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
            makeButton(title: L10n.Toolbar.view, icon: "eye.circle", action: onView)
            makeButton(title: L10n.Toolbar.edit, icon: "pencil", action: onEdit)
            makeButton(title: L10n.Toolbar.copy, icon: "doc.on.doc", action: onCopy)
            makeButton(title: L10n.Toolbar.move, icon: "square.and.arrow.down.on.square", action: onMove)
            makeButton(title: L10n.Toolbar.newFolder, icon: "folder.badge.plus", action: onNewFolder)
            makeButton(title: L10n.Toolbar.delete, icon: "minus.rectangle", action: onDelete)
            makeButton(title: L10n.Toolbar.settings, icon: "gearshape", action: onSettings)
            makeButton(title: L10n.Toolbar.console, icon: "terminal", action: onConsole)
            makeButton(title: L10n.Toolbar.exit, icon: "power", action: onExit)
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

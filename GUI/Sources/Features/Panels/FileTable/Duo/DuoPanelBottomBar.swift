//
// DuoPanelBottomToolbarSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Bottom toolbar with action buttons and optional thumbnail size slider
struct DuoPanelBottomToolbarSection: View {
    let onRename: () -> Void
    let onBackup: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onMove: () -> Void
    let onNewFolder: () -> Void
    let onDelete: () -> Void
    let onExit: () -> Void

    @Environment(AppState.self) var appState
    
    private enum Layout {
        static let toolbarHorizontalPadding: CGFloat = 18
        static let toolbarTopPadding: CGFloat = 8
        static let toolbarBottomPadding: CGFloat = 12
        static let toolbarButtonSpacing: CGFloat = 7
    }
    
    var body: some View {
        let store = HotKeyStore.shared
        VStack(spacing: 0) {
            HStack(spacing: Layout.toolbarButtonSpacing) {
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.rename, for: .renameFile), icon: "pencil", action: onRename)
                DownToolbarButtonView(
                    title: store.buttonLabel(L10n.Toolbar.tempBackup, for: .backupFiles),
                    systemImage: "zipper.page",
                    imageName: "TempBackupZip",
                    action: onBackup
                )
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.edit, for: .editFile), icon: "pencil", action: onEdit)
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.copy, for: .copyFile), icon: "doc.on.doc", action: onCopy)
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.move, for: .moveFile), icon: "square.and.arrow.down.on.square", action: onMove)
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.newFolder, for: .newFolder), icon: "folder.badge.plus", action: onNewFolder)
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.delete, for: .deleteFile), icon: "trash", action: onDelete)
                downToolBarButton(title: store.buttonLabel(L10n.Toolbar.exit, for: .exitApp), icon: "power", action: onExit)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.toolbarHorizontalPadding)
            .padding(.top, Layout.toolbarTopPadding)
            .padding(.bottom, Layout.toolbarBottomPadding)
        }
        .background(
            DuoPanelToolbarBackground(cornerRadius: 0)
        )
        .overlay(alignment: .top) {
            Color(nsColor: .separatorColor).opacity(0.7)
                .frame(height: 1)
        }
    }
    
    private func downToolBarButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        DownToolbarButtonView(
            title: title,
            systemImage: icon,
            action: action
        )
    }
}

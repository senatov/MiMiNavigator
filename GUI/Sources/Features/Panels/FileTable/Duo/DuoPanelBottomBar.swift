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
        static let toolbarTopPadding: CGFloat = 9
        static let toolbarBottomPadding: CGFloat = 20
        static let toolbarButtonSpacing: CGFloat = 8
    }

    var body: some View {
        let store = HotKeyStore.shared
        VStack(spacing: 0) {
            HStack(spacing: Layout.toolbarButtonSpacing) {
                commanderButton(title: L10n.Toolbar.rename, action: .renameFile, icon: "character.cursor.ibeam", tint: .orange, handler: onRename)
                CommanderActionButton(
                    title: L10n.Toolbar.tempBackup,
                    shortcut: store.shortcutString(for: .backupFiles),
                    systemImage: "zipper.page",
                    iconTint: .blue,
                    action: onBackup
                )
                commanderButton(title: L10n.Toolbar.edit, action: .editFile, icon: "pencil.line", tint: .indigo, handler: onEdit)
                commanderButton(title: L10n.Toolbar.copy, action: .copyFile, icon: "doc.on.doc", tint: .blue, handler: onCopy)
                commanderButton(
                    title: L10n.Toolbar.move, action: .moveFile, icon: "square.and.arrow.down.on.square", tint: .teal, handler: onMove)
                commanderButton(
                    title: L10n.Toolbar.newFolder, action: .newFolder, icon: "folder.badge.plus", tint: .green, handler: onNewFolder)
                commanderButton(title: L10n.Toolbar.delete, action: .deleteFile, icon: "trash", tint: .red, handler: onDelete)
                commanderButton(title: L10n.Toolbar.exit, action: .exitApp, icon: "power", tint: .purple, handler: onExit)
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

    // MARK: - Commander Button
    private func commanderButton(title: String, action: HotKeyAction, icon: String, tint: Color, handler: @escaping () -> Void)
        -> some View
    {
        CommanderActionButton(
            title: title,
            shortcut: HotKeyStore.shared.shortcutString(for: action),
            systemImage: icon,
            iconTint: tint,
            action: handler
        )
    }
}

// MARK: - Commander Action Button
private struct CommanderActionButton: View {
    let title: String
    let shortcut: String
    let systemImage: String
    let iconTint: Color
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                elementDivider
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(shortcutColor)
                        .fixedSize()
                    elementDivider
                }
                Text(title)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.primary)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: 84)
        }
        .buttonStyle(DownToolbarGlassButtonStyle(isHovered: isHovered, horizontalPadding: 9, verticalPadding: 7, raised: true))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .keyboardFocusable()
        .help(shortcut.isEmpty ? title : "\(title) (\(shortcut))")
        .accessibilityLabel(title)
        .accessibilityHint(shortcut.isEmpty ? "" : "Keyboard shortcut \(shortcut)")
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .light))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(iconTint)
            .frame(width: 18, height: 18)
    }

    private var elementDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 17)
    }

    private var shortcutColor: Color {
        if colorScheme == .dark { return Color(nsColor: .systemBlue) }
        return Color(#colorLiteral(red: 0.07450980392, green: 0.2666666667, blue: 0.5098039216, alpha: 1))
    }
}

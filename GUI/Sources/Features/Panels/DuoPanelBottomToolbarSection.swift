//
// DuoPanelBottomToolbarSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import FileModelKit

/// Bottom toolbar with action buttons and optional thumbnail size slider
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

    @State private var viewModeStore = PanelViewModeStore.shared
    @Environment(AppState.self) var appState
    
    private enum Layout {
        static let toolbarHorizontalPadding: CGFloat = 16
        static let toolbarVerticalPadding: CGFloat = 12
        static let toolbarCornerRadius: CGFloat = 10
        static let toolbarOuterPadding: CGFloat = 8
        static let toolbarBottomPadding: CGFloat = 8
        static let toolbarButtonSpacing: CGFloat = 12
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail size slider — visible only when focused panel is in thumbnail mode
            let side = appState.focusedPanel
            if viewModeStore.mode(for: side) == .thumbnail {
                ThumbnailSizeSlider(panelSide: side, store: viewModeStore)
                    .padding(.horizontal, Layout.toolbarHorizontalPadding)
                    .padding(.top, 4)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }

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
        }
        .background(
            DuoPanelToolbarBackground(cornerRadius: Layout.toolbarCornerRadius)
        )
        .padding(.horizontal, Layout.toolbarOuterPadding)
        .padding(.bottom, Layout.toolbarBottomPadding)
        .animation(.easeInOut(duration: 0.18), value: viewModeStore.mode(for: appState.focusedPanel))
    }
    
    private func makeButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        DownToolbarButtonView(
            title: title,
            systemImage: icon,
            action: action
        )
    }
}

// MARK: - ThumbnailSizeSlider

private struct ThumbnailSizeSlider: View {
    let panelSide: PanelSide
    let store: PanelViewModeStore

    private var sizeBinding: Binding<CGFloat> {
        Binding(
            get: { store.thumbSize(for: panelSide) },
            set: { store.setThumbSize($0, for: panelSide) }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(value: sizeBinding, in: 80...300, step: 10)
                .frame(maxWidth: 200)
                .controlSize(.small)
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("\(Int(store.thumbSize(for: panelSide))) pt")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

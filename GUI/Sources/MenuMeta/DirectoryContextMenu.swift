//
//  DirectoryContextMenu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

/// Popup-like menu shown on hover and reused by right-click context menu.
struct DirectoryContextMenu: View {
    let file: CustomFile
    let onAction: (DirectoryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(.open)
            menuButton(.openInNewTab)
            menuButton(.viewLister)
            Divider()
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.pack)
            menuButton(.createLink)
            Divider()
            menuButton(.delete)
            menuButton(.rename)
            Divider()
            menuButton(.properties)
        }
        .frame(minWidth: 220)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .secondary.opacity(0.25), radius: 7, x: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 0.6)
        )
    }

    /// Creates a single menu button row for a given directory action.
    @ViewBuilder
    private func menuButton(_ action: DirectoryAction) -> some View {
        Button {
            // Primitive logging only, as requested
            log.debug("Dir menu action: \(action.rawValue) → \(file.pathStr)")
            onAction(action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .frame(width: 16)
                Text(action.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}

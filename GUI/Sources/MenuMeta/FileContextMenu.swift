//
//  FileContextMenu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

//
//  FileContextMenu.swift
//  MiMiNavigator
//

import Foundation
import SwiftUI

/// Context menu for non-directory file items.
struct FileContextMenu: View {
    let file: CustomFile
    let onAction: (FileAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.pack)
            menuButton(.viewLister)
            Divider()
            menuButton(.createLink)
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

    // Creates one row for a given action.
    @ViewBuilder
    private func menuButton(_ action: FileAction) -> some View {
        Button {
            // Primitive logging only, as requested
            log.debug("File menu action: \(action.rawValue) → \(file.pathStr)")
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

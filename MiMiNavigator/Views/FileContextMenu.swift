// FileContextMenu.swift
//  MiMiNavigator

// Context menu for file actions such as Copy, Rename, Delete
//  Created by Iakov Senatov on 25.10.24.

import SwiftUI
import SwiftyBeaver

/// Context menu for file actions

// MARK: - -

struct FileContextMenu: View {
    // Initialize logger
    let log = SwiftyBeaver.self
    var body: some View {
        Group {
            Button(action: {
                // Copy action
                log.debug("Copy action triggered")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(PlainButtonStyle()) // Apply plain style
            .foregroundColor(.primary) // Default system color

            Button(action: {
                // Rename action
                log.debug("Rename action triggered")
            }) {
                Label("Rename", systemImage: "pencil")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.primary)

            Button(action: {
                // Delete action
                log.debug("Delete action triggered")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.primary)
        }
    }
}

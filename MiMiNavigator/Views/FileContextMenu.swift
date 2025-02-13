// FileContextMenu.swift
//  MiMiNavigator

// Context menu for file actions such as Copy, Rename, Delete
//  Created by Iakov Senatov on 25.10.24.

import SwiftUI
import SwiftyBeaver

// MARK: - Context menu for file actions

struct FileContextMenu: View {
    // Initialize logger
    var body: some View {
        Group {
            Button(action: {
                // Copy action
                LoggerManager.log.debug("Copy action triggered")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary) // Default system color

            Button(action: {
                // Rename action
                LoggerManager.log.debug("Rename action triggered")
            }) {
                Label("Rename", systemImage: "pencil")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)

            Button(action: {
                // Delete action
                LoggerManager.log.debug("Delete action triggered")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
        }
    }
}

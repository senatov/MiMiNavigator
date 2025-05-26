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
                log.info("Copy action triggered")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)  // Default system color

            Button(action: {
                // Rename action
                log.info("Rename action triggered")
            }) {
                Label("Rename", systemImage: "pencil")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)

            Button(action: {
                // Delete action
                log.info("Delete action triggered")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
struct FileContextMenu_Previews: PreviewProvider {
    static var previews: some View {
        FileContextMenu()
    }
}

// FileContextMenu.swift
//  MiMiNavigator

// Context menu for file actions such as Copy, Rename, Delete
//  Created by Iakov Senatov on 25.10.24.

import SwiftUI

/// Context menu for file actions
struct FileContextMenu: View {
    var body: some View {
        Group {
            Button(action: {
                // Copy action
                print("Copy action triggered")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(PlainButtonStyle()) // Apply plain style
            .foregroundColor(.primary) // Default system color

            Button(action: {
                // Rename action
                print("Rename action triggered")
            }) {
                Label("Rename", systemImage: "pencil")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.primary)

            Button(action: {
                // Delete action
                print("Delete action triggered")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.primary)
        }
    }
}

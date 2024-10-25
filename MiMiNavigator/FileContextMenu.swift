// FileContextMenu.swift
// Context menu for file actions such as Copy, Rename, Delete
//  Created by Iakov Senatov on 25.10.24.

import SwiftUI

    /// Context menu for file actions
struct FileContextMenu: View {
    var body: some View {
        Group {
            Button {
                    // Copy action
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                    // Rename action
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                    // Delete action
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

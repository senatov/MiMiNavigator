//
//  TreeView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

//  Description:
//

import SwiftUI

/// A view that recursively displays files and folders as a tree structure.
///
/// This view takes an array of `CustomFile` objects and displays them as a list.
/// If a file has children, it will create a nested list to represent the tree structure.
/// Handles click events to update the selected file.

// MARK: - -

struct TreeView: View {
    let files: [CustomFile]
    @Binding var selectedFile: CustomFile?

    var body: some View {
        List(files, children: \.children) { file in
            Text(file.name)
                .onTapGesture {
                    selectedFile = file
                    print("Selected file: \(file.name)")
                }
                .contextMenu {
                    Button(action: {
                        print("Copy action for \(file.name)")
                    }) {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    .buttonStyle(PlainButtonStyle()) // Apply plain style
                    .foregroundColor(.primary) // System default color

                    Button(action: {
                        print("Rename action for \(file.name)")
                    }) {
                        Label("Rename", systemImage: "penpencil.circle")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.primary)

                    Button(action: {
                        print("Delete action for \(file.name)")
                    }) {
                        Label("Delete", systemImage: "eraser.line.dashed")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.primary)

                    Button(action: {
                        print("More info action for \(file.name)")
                    }) {
                        Label("More Info", systemImage: "info.circle.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.primary)
                }
        }
    }
}

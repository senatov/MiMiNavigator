    //
    //  SwiftUI.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 06.10.24.
    //

import SwiftUI

    /// A view that recursively displays files and folders as a tree structure.
    ///
    /// This view takes an array of `CustomFile` objects and displays them as a list.
    /// If a file has children, it will create a nested list to represent the tree structure.
    /// Handles click events to update the selected file.
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
                    Button {
                            // Action for copying
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    .foregroundColor(.blue)  // Standard user color
                    
                    Button {
                            // Action for renaming
                    } label: {
                        Label("Rename", systemImage: "penpencil.circle")
                    }
                    .foregroundColor(.blue)  // Standard user color
                    
                    Button {
                            // Action for deleting
                    } label: {
                        Label("Delete", systemImage: "eraser.line.dashed")
                    }
                    .foregroundColor(.blue)  // Standard user color
                    
                    Button {
                            // Additional action
                    } label: {
                        Label("More Info", systemImage: "info.circle.fill")
                    }
                    .foregroundColor(.blue)  // Standard user color
                }
        }
    }
}

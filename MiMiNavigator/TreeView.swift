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
                        // Handle click event to select the file
                    selectedFile = file
                    print("Selected file: \(file.name)")
                }
                .contextMenu {
                    Button {
                            // Copy action
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    Button {
                            // Rename action
                    } label: {
                        Label("Rename", systemImage: "penpencil.circle")
                    }
                    Button {
                            // Delete action
                    } label: {
                        Label("Delete", systemImage: "eraser.line.dashed")
                    }
                    Button {
                            // Additional action
                    } label: {
                        Label("More Info", systemImage: "info.circle.fill")
                    }
                }
        }
    }
}

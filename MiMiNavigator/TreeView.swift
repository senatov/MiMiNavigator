import SwiftUI

    /// A view that recursively displays files and folders as a tree structure.
    ///
    /// This view takes an array of `File` objects and displays them as a list.
    /// If a file has children, it will create a nested list to represent the tree structure.
    /// Handles click events to update the selected file.
struct TreeView: View {
    let files: [File]
    @Binding var selectedFile: File?
    
    var body: some View {
        List(files, children: \.children) { file in
            Text(file.name)
                .onTapGesture {
                        // Handle click event to select the file
                    selectedFile = file
                    print("Selected file: \(file.name)")
                }
                .contextMenu {
                    Button(action: {
                            // Copy action
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    }
                    Button(action: {
                            // Rename action
                    }) {
                        Text("Rename")
                        Image(systemName: "pencil")
                    }
                    Button(action: {
                            // Delete action
                    }) {
                        Text("Delete")
                        Image(systemName: "trash")
                    }
                    Button(action: {
                            // Additional action
                    }) {
                        Text("More Info")
                        Image(systemName: "info.circle")
                    }
                }
        }
    }
}

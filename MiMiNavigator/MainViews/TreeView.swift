    //
    //  TreeView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.
    //

import SwiftUI
import SwiftyBeaver


struct TreeView: View {
    @Binding var files: [CustomFile]
    @Binding var selectedFile: CustomFile?
    
    @State private var expandedFolders: Set<String> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach($files, id: \.path) { $file in
                    FavTreeRowView(
                        file: $file,
                        selectedFav: $selectedFile,
                        expandedFolders: $expandedFolders
                    )
                }
            }
        }
        .padding()
    }
}


    // MARK: - Preview
struct TreeView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = CustomFile(
            name: "Test",
            path: "/tmp/test",
            isDirectory: true,
            children: [
                CustomFile(name: "Subfolder", path: "/tmp/test/sub", isDirectory: true, children: [
                    CustomFile(name: "file.txt", path: "/tmp/test/sub/file.txt", isDirectory: false, children: nil)
                ])
            ]
        )
        return TreeView(
            files: .constant([sample]),
            selectedFile: .constant(nil)
        )
    }
}

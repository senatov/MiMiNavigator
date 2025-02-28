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
                ForEach($files) { $file in
                    TreeRowView(
                        file: $file,
                        selectedFile: $selectedFile,
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
    @State static var previewSelectedFile: CustomFile? = nil

    static let previewFileStructure: [CustomFile] = [
        CustomFile(
            name: "Root",
            path: "/Root",
            isDirectory: true,
            children: [
                CustomFile(
                    name: "Folder 1",
                    path: "/Root/Folder1",
                    isDirectory: true,
                    children: [
                        CustomFile(name: "File 1", path: "/Root/Folder1/File1", isDirectory: false),
                        CustomFile(name: "File 2", path: "/Root/Folder1/File2", isDirectory: false),
                    ]
                ),
                CustomFile(name: "Folder 2", path: "/Root/Folder2", isDirectory: true, children: []),
            ]
        )
    ]

    static var previews: some View {
        TreeView(files: .constant(previewFileStructure), selectedFile: $previewSelectedFile)
            .frame(maxWidth: 250)
            .font(.caption)
            .padding()
    }
}

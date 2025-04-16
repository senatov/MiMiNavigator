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
                    FavTreeView(
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

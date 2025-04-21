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
        VStack(alignment: .leading, spacing: 0) {
            Text("Favorites:")
                .font(.headline)
                .foregroundColor(Color(#colorLiteral(red: 0.06274510175, green: 0, blue: 0.1921568662, alpha: 1)))
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            Divider()
                .padding(.horizontal)
                .padding(.vertical, 6)
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
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10))
        .padding()
    }
}

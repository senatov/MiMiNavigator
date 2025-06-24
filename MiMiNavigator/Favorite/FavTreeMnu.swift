//
//  FavTreeMnu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//

import SwiftUI
import SwiftyBeaver

struct FavTreeMnu: View {
    @Binding var files: [CustomFile]
    @State private var expandedFolders: Set<String> = []
    @EnvironmentObject var appState: AppState


    // MARK: -
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            dividerView
            fileListView
        }
        .frame(width: 450)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                )
        )
        .padding()
    }


    // MARK: -
    private var headerView: some View {
        log.info(#function)
        return Text("Favorites:")
            .font(.headline)
            .foregroundColor(Color(#colorLiteral(red: 0.06274510175, green: 0, blue: 0.1921568662, alpha: 1)))
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: -
    private var dividerView: some View {
        Divider()
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    // MARK: -
    private var fileListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach($files) { $file in
                    FavTreeView(file: $file, expandedFolders: $expandedFolders)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}

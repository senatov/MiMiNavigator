//
//  FavoritesTreeViewModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import SwiftUI

@MainActor
final class FavoritesTreeViewModel: ObservableObject {
    @Published var expandedFolders: Set<String> = []
    @Published var selectedFile: CustomFile?

    func toggleExpansion(for file: CustomFile) {
        if expandedFolders.contains(file.pathStr) {
            expandedFolders.remove(file.pathStr)
        } else {
            expandedFolders.insert(file.pathStr)
        }
    }
}
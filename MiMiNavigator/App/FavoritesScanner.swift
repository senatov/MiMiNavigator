//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// This class scans the "Favorites" directory on macOS and builds a CustomFile structure
class FavoritesScanner {
    // Scans the user's "Favorites" folder and returns it as a hierarchy of CustomFile objects
    func scanFavorites() -> [CustomFile] {
        // macOS typically stores "Favorites" in the sidebar, which can include folders like "Desktop", "Documents", etc.
        // For simplicity, we'll assume Favorites are located in a specific path, such as "/Users/username/Favorites".
        // Adjust the path as needed.
        let favoritesPaths = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures"),
        ]

        var favorites: [CustomFile] = []
        for path in favoritesPaths {
            if let customFile = buildFileStructure(at: path) {
                favorites.append(customFile)
            }
        }
        return favorites
    }

    // Recursively builds the file structure for a given directory
    private func buildFileStructure(at url: URL) -> CustomFile? {
        let fileManager = FileManager.default
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let fileName = url.lastPathComponent

        var children: [CustomFile]?
        if isDirectory {
            let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
            children = contents.compactMap { buildFileStructure(at: $0) }
        }
        return CustomFile(name: fileName, path: url.path, isDirectory: isDirectory, children: children)
    }
}

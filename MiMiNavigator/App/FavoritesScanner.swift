//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

    // This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavoritesScanner {
    
        // MARK: - Scans standard directories in Finder (e.g., Desktop, Documents) and returns a hierarchy of CustomFile objects
    
    func scanFavorites() -> [CustomFile] {
        let favoritePaths = getStandardFavoritePaths() // Retrieve standard favorites paths
        var favorites: [CustomFile] = []
        
        for path in favoritePaths {
            if let customFile = buildFileStructure(at: path) {
                favorites.append(customFile)
            }
        }
        return favorites
    }
    
        // MARK: - Recursively builds the file structure for a given directory
    
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
    
        // MARK: - Retrieves standard favorites paths (Desktop, Documents, Downloads, Pictures)
    
    private func getStandardFavoritePaths() -> [URL] {
        let fileManager = FileManager.default
        
        return [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentationDirectory, in: .networkDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .developerDirectory, in: .userDomainMask).first
        ].compactMap { $0 } // Filters out nil values if any paths are missing
    }
}

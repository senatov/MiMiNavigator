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
    private var visitedPaths = Set<URL>()

    // MARK: -
    public func scanFavorites() -> [CustomFile] {
        LoggerManager.log.debug("scanFavorites()")
        let favoritePaths = FileManager.default.allDirectories
        return favoritePaths.compactMap { buildFileStructure(at: $0, maxDirectories: 0xFF) }
    }

    // MARK: -
    private func buildFileStructure(at url: URL, maxDirectories: Int = 0xFF) -> CustomFile? {
        LoggerManager.log.debug("buildFileStructure() at \(url.path)")
        // Avoid revisiting the same path
        guard !visitedPaths.contains(url) else {
            return nil
        }
        visitedPaths.insert(url)
        // Check if the URL is a symbolic link
        let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard resourceValues?.isSymbolicLink != true else {
            return nil
        }
        // Determine if the URL is a directory
        let isDirectory = resourceValues?.isDirectory ?? false
        let fileName = url.lastPathComponent
        // If it's a directory, scan its contents
        var children: [CustomFile]?
        if isDirectory {
            let contents =
                (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                )) ?? []

            // Limit the number of directories to scan
            children = contents.prefix(maxDirectories).compactMap { buildFileStructure(at: $0, maxDirectories: 0) }
        }
        return CustomFile(name: fileName, path: url.path, isDirectory: isDirectory, children: children)
    }
}

//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

/// This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavScanner {

    // Limits for the breadth and depth of directory scanning
    private let maxDirectories: Int = 11
    // Limits for the breadth and depth of directory scanning
    private let maxDepth: Int = 1
    private var currentDepth: Int = 0

    // MARK: - Entry Point: Scans favorite directories and builds their file trees
    func scanFavorites() -> [CustomFile] {
        log.debug("scanFavorites() started")
        let favoritePaths = FileManager.default.allDirectories
        let trees = favoritePaths.compactMap { buildFavTreeStructure(at: $0) }
        log.debug("Total directory branches across all favorite trees: \(trees.count)")
        return trees
    }

    private var visitedPaths = Set<URL>()

    // MARK: - Iterative File Structure Scanner (BFS)
    private func buildFavTreeStructure(at url: URL) -> CustomFile? {
        currentDepth += 1
        log.debug("buildFavTreeStructure() depth: \(currentDepth) at \(url.path)")
        // Avoid revisiting the same path
        guard !visitedPaths.contains(url) else {
            return nil
        }
        visitedPaths.insert(url)
        // Check if the URL is a symbolic link, not a directory, or hidden
        let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey])
        if resourceValues?.isSymbolicLink == true {
            return nil
        }
        if resourceValues?.isHidden == true {
            return nil
        }
        guard resourceValues?.isDirectory == true else {
            return nil
        }
        let maxDisplayWidth: Int = 30  // approx. character limit to fit the visual frame
        var fileName = url.lastPathComponent
        if fileName.count > maxDisplayWidth {
            fileName = String(fileName.prefix(maxDisplayWidth - 3)) + "..."
        }
        var children: [CustomFile]?
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        if currentDepth <= maxDepth {
            children = contents.prefix(maxDirectories).compactMap {
                guard let values = try? $0.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey]) else {
                    return nil
                }
                if values.isSymbolicLink == true || values.isHidden == true {
                    return nil
                }
                if values.isDirectory != true {
                    return nil
                }
                return buildFavTreeStructure(at: $0)
            }
        }
        return CustomFile(name: fileName, path: url.path, isDirectory: true, children: children)
    }
}

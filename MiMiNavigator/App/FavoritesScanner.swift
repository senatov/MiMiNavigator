    //
    //  FavoritesScanner.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 01.11.24.
    //  Copyright © 2024 Senatov. All rights reserved.
    //

import Foundation

    /// Scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavoritesScanner {
    private var favPaths = Set<URL>()
    
        // MARK: - Public Method
    public func scanFavorites() -> [CustomFile] {
        LogMan.log.debug("scanFavorites()")
        favPaths.removeAll()  // Очистка перед новым сканированием
        return FavTreePanel.allDirectories.compactMap {
            buildFavTreeStructure(at: $0, maxDirectories: 0xFF)
        }
    }
    
        // MARK: - Fav Scanner
    private func buildFavTreeStructure(at rootURL: URL, maxDirectories: Int = 0xFF, maxDepth: Int = 3) -> CustomFile? {
        LogMan.log.debug("buildFileStructure() for \(rootURL.path)")
        guard favPaths.insert(rootURL).inserted else {
            LogMan.log.warning("Skipped duplicate scan of directory: \(rootURL.path)")
            return nil
        }
        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var fileMap = [URL: CustomFile]()
        var rootFile: CustomFile?
        while !queue.isEmpty {
            let (currentURL, currentDepth) = queue.removeFirst()
            if shouldSkipURL(currentURL) { continue }
            
            let isDirectory = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let fileNode = makeCustomFile(from: currentURL, isDirectory: isDirectory)
            fileMap[currentURL] = fileNode
            if rootFile == nil { rootFile = fileNode }
            guard isDirectory, currentDepth < maxDepth else { continue }
            
            let nextLevel = processContents(of: currentURL, depth: currentDepth, fileMap: &fileMap)
            for child in nextLevel {
                queue.append((child, currentDepth + 1))
            }
        }
        return rootFile
    }
    
    private func shouldSkipURL(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
            LogMan.log.warning("Skipping \(url.path): cannot retrieve resource values.")
            return true
        }
        if resourceValues.isSymbolicLink == true {
            LogMan.log.warning("Skipping symbolic link: \(url.path)")
            return true
        }
        return false
    }
    
    private func makeCustomFile(from url: URL, isDirectory: Bool) -> CustomFile {
        return CustomFile(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: isDirectory,
            children: isDirectory ? [] : nil
        )
    }
    
    private func processContents(of parentURL: URL, depth: Int, fileMap: inout [URL: CustomFile]) -> [URL] {
        var childrenToQueue = [URL]()
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            for item in contents.prefix(0xFF) {
                if favPaths.contains(item) { continue }
                favPaths.insert(item)
                guard let isItemDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory else { continue }
                childrenToQueue.append(item)
                var name = item.lastPathComponent
                let lowerPath = item.path.lowercased()
                if lowerPath.contains("icloud") {
                    name = "iCloud"
                } else if lowerPath.contains("onedrive") {
                    name = "MS OneDrive"
                } else if lowerPath.contains("support") {
                    name = "App. Support"
                } else if lowerPath.contains("users") {
                    name = "HomeDir"
                }
                let tempNode = CustomFile(name: name, path: item.path, isDirectory: isItemDirectory, children: isItemDirectory ? [] : nil)
                fileMap[parentURL]?.children?.append(tempNode)
                fileMap[item] = tempNode
            }
        } catch {
            LogMan.log.error("Failed reading directory: \(parentURL.path), error: \(error.localizedDescription)")
        }
        return childrenToQueue
    }
}

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
    private var totalDirectoryCount = 0
    private let maxDirectories: Int = 125
    private let maxDepth: Int = 3
    
        // MARK: - Public Method
    public func scanFavorites() -> [CustomFile] {
        log.debug("scanFavorites()")
        favPaths.removeAll()  // Очистка перед новым сканированием
        return FavTreePanel.allDirectories.compactMap {
            buildFavTreeStructure(at: $0)
        }
    }
    
        // MARK: - Fav Scanner
    private func buildFavTreeStructure(at rootURL: URL) -> CustomFile? {
        log.debug("buildFileStructure() for \(rootURL.path)")
        totalDirectoryCount = 0
        guard favPaths.insert(rootURL).inserted else {
            log.warning("Skipped duplicate scan of directory: \(rootURL.path)")
            return nil
        }
        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var fileMap = [URL: CustomFile]()
        var rootFile: CustomFile?
        while !queue.isEmpty {
            let (currURL, currDepth) = queue.removeFirst()
            if shouldSkipURL(currURL) { continue }
            
            let isDirectory = (try? currURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let fileNode = makeCustomFile(from: currURL, isDirectory: isDirectory)
            fileMap[currURL] = fileNode
            if rootFile == nil { rootFile = fileNode }
            guard isDirectory, currDepth < self.maxDepth else { continue }
            
            let nextLevel = processContents(of: currURL, depth: currDepth, maxDirs: self.maxDirectories, fileMap: &fileMap)
            for child in nextLevel {
                queue.append((child, currDepth + 1))
            }
        }
        return rootFile
    }
        // MARK: -
    private func shouldSkipURL(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
            log.warning("Skipping \(url.path): cannot retrieve resource values.")
            return true
        }
        if resourceValues.isSymbolicLink == true {
            log.warning("Skipping symbolic link: \(url.path)")
            return true
        }
        return false
    }
        // MARK: -
    private func makeCustomFile(from url: URL, isDirectory: Bool) -> CustomFile {
        return CustomFile(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: isDirectory,
            children: isDirectory ? [] : nil
        )
    }
        // MARK: -
    private func processContents(of parentURL: URL, depth: Int, maxDirs: Int, fileMap: inout [URL: CustomFile]) -> [URL] {
        var childrenToQueue = [URL]()
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            for item in contents.prefix(0xFF) {
                log.debug("🔍 Scanning item: \(item.path)")
                
                if favPaths.contains(item) {
                    log.debug("⛔️ Skipped (already seen): \(item.lastPathComponent)")
                    continue
                }
                favPaths.insert(item)
                
                guard let isItemDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory else {
                    log.debug("❓ Skipped (cannot determine isDirectory): \(item.lastPathComponent)")
                    continue
                }
                
                if totalDirectoryCount >= maxDirs {
                    log.warning("🚧 Directory limit reached at \(parentURL.path)")
                    return childrenToQueue
                }
                totalDirectoryCount += 1
                log.debug("✅ Queued item: \(item.lastPathComponent)")
                childrenToQueue.append(item)
                let name: String
                name = item.lastPathComponent
                let tempNode = CustomFile(name: name, path: item.path, isDirectory: isItemDirectory, children: isItemDirectory ? [] : nil)
                if var parent = fileMap[parentURL] {
                    if parent.children == nil {
                        parent.children = []
                    }
                    parent.children?.append(tempNode)
                    fileMap[parentURL] = parent
                }
                fileMap[item] = tempNode
            }
        } catch {
            log.error("Failed reading directory: \(parentURL.path), error: \(error.localizedDescription)")
        }
        return childrenToQueue
    }
}

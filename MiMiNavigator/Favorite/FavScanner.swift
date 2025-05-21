    //
    //  FavoritesScanner.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 01.11.24.
    //  Copyright © 2024 Senatov. All rights reserved.
    //

import AppKit
import FilesProvider
import Foundation

    // MARK: - This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
@MainActor
class FavScanner {
    
    private var visitedPaths = Set<URL>()
        // Limits for the breadth and depth of directory scanning
    private let maxDirectories: Int = 64
    private let maxDepth: Int = 2
    private var currentDepth: Int = 0
    
        // MARK: - Entry Point: Scans favorite directories and builds their file trees
    func scanFavoritesAndNetworkVolumes(completion: @escaping ([CustomFile]) -> Void) {
        visitedPaths.removeAll()
        log.debug(#function)
        _ = LocalFileProvider()
        var favorites: [CustomFile] = []
        var icloud: [CustomFile] = []
        var network: [CustomFile] = []
        var localDisks: [CustomFile] = []
        let favoriteURLs = FileManager.default.allDirectories
        favorites = favoriteURLs.compactMap { buildFavTreeStructure(at: $0) }
            // iCloud Drive fallback
        let icloudURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: icloudURL.path) {
            if let node = buildFavTreeStructure(at: icloudURL) {
                icloud.append(node)
            }
        }
        
            // OneDrive fallback (scan all OneDrive variants under CloudStorage)
        var oneDrive: [CustomFile] = []
        let cloudStorageURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(
            "Library/CloudStorage"
        )
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: cloudStorageURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for item in contents where item.lastPathComponent.hasPrefix("OneDrive") {
                if FileManager.default.fileExists(atPath: item.path),
                   let node = buildFavTreeStructure(at: item)
                {
                oneDrive.append(node)
                }
            }
        }
        
        Task { @MainActor in
            self.requestAccessToVolumesDirectory { volumesURL in
                guard let volumesURL = volumesURL else {
                    log.error("User did not grant access to /Volumes")
                    let result: [CustomFile] = [
                        CustomFile(name: "Favorites", path: "", children: favorites),
                        CustomFile(name: "iCloud Drive", path: "", children: icloud),
                        CustomFile(name: "OneDrive", path: "", children: oneDrive),
                    ]
                    completion(result)
                    return
                }
                
                if let contents = try? FileManager.default.contentsOfDirectory(
                    at: volumesURL,
                    includingPropertiesForKeys: nil
                ) {
                    for url in contents
                    where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        guard FileManager.default.fileExists(atPath: url.path) else { continue }
                        var isNetwork = false
                        let key = URLResourceKey("volumeIsNetwork")
                        let values = try? url.resourceValues(forKeys: [key])
                        isNetwork = (values?.allValues[key] as? Bool) ?? false
                        
                        if isNetwork {
                            if let node = self.buildFavTreeStructure(at: url) {
                                network.append(node)
                            }
                        } else {
                            if let node = self.buildFavTreeStructure(at: url) {
                                localDisks.append(node)
                            }
                        }
                    }
                } else {
                    log.error("Cannot read /Volumes contents even after user granted access.")
                }
                
                var result: [CustomFile] = []
                if !favorites.isEmpty {
                    result.append(CustomFile(name: "Favorites", path: .empty, children: favorites))
                }
                if !icloud.isEmpty {
                    result.append(CustomFile(name: "iCloud Drive", path: .empty, children: icloud))
                }
                if !oneDrive.isEmpty {
                    result.append(CustomFile(name: "OneDrive", path: .empty, children: oneDrive))
                }
                if !network.isEmpty {
                    result.append(CustomFile(name: "Network Volumes", path: .empty, children: network))
                }
                if !localDisks.isEmpty {
                    result.append(CustomFile(name: "Local Volumes", path: .empty, children: localDisks))
                }
                log.debug("Total groups: \(result.count)")
                completion(result)
                volumesURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    
        // MARK: -
    func scanOnlyFavorites() -> [CustomFile] {
        log.debug(#function)
        let favoritePaths = FileManager.default.allDirectories
        let trees = favoritePaths.compactMap { buildFavTreeStructure(at: $0) }
        log.debug("Total directory branches: \(trees.count)")
        return trees
    }
    
        // MARK: - Iterative File Structure Scanner (BFS)
    private func buildFavTreeStructure(at url: URL) -> CustomFile? {
        log.debug(#function)
        currentDepth += 1
        defer { currentDepth -= 1 }
        log.debug("buildFavTreeStructure() depth: \(currentDepth) at \(url.path)")
            // Avoid revisiting the same path
        guard !visitedPaths.contains(url) else {
            return nil
        }
        visitedPaths.insert(url)
        guard isValidDirectory(url) else {
            return nil
        }
            // approx. character limit to fit the visual frame
        let maxDisplayWidth: Int = 75
        var fileName = url.lastPathComponent
        if fileName.count > maxDisplayWidth {
            fileName = String(fileName.prefix(maxDisplayWidth - 3)) + "..."
        }
        
        let children = buildChildren(for: url)
        return CustomFile(name: fileName, path: url.path, children: children)
    }
    
        // MARK: -
    private func isValidDirectory(_ url: URL) -> Bool {
        log.debug(#function)
        let keys: [URLResourceKey] = [
            .isSymbolicLinkKey,
            .isDirectoryKey,
            .isHiddenKey,
            .fileResourceTypeKey,
            .typeIdentifierKey,
        ]
        let values = try? url.resourceValues(forKeys: Set(keys))
            // Skip hidden items
        if values?.isHidden == true {
            return false
        }
            // Resolve and validate symbolic links
        if values?.isSymbolicLink == true {
            let resolvedURL = url.resolvingSymlinksInPath()
            var isDirFS: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirFS) {
                return isDirFS.boolValue
            }
                // Fallback to resource values on resolved URL
            let resolvedValues = try? resolvedURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileResourceTypeKey,
            ])
            if resolvedValues?.isDirectory == true || resolvedValues?.fileResourceType == .directory {
                return true
            }
            return false
        }
            // Accept genuine directories
        if values?.isDirectory == true {
            return true
        }
            // Fallback: accept if fileResourceType indicates a directory
        if values?.fileResourceType == .directory {
            return true
        }
            // Final fallback via FileManager
        var isDirFS: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirFS) {
            return isDirFS.boolValue
        }
        return false
    }
    
        // MARK: -
    private func buildChildren(for url: URL) -> [CustomFile]? {
        log.debug(#function)
        var result: [CustomFile]? = nil
        if currentDepth <= maxDepth {
            let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .fileResourceTypeKey,
                    .typeIdentifierKey,
                ],
                options: [.skipsHiddenFiles]
            )) ?? []
            let validDirectories = contents.prefix(maxDirectories).filter { url in
                guard
                    let values = try? url.resourceValues(forKeys: [
                        .isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey,
                        .fileResourceTypeKey, .typeIdentifierKey,
                    ])
                else {
                    return false
                }
                    // Skip hidden items
                if values.isHidden == true {
                    return false
                }
                    // Resolve symlinks if needed
                if values.isSymbolicLink == true {
                    let resolved = url.resolvingSymlinksInPath()
                    return (try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                }
                    // Accept genuine directories
                if values.isDirectory == true {
                    return true
                }
                    // Fallback: accept if fileResourceTypeKey says it's a directory
                if values.fileResourceType == .directory {
                    return true
                }
                    // Final fallback via FileManager
                var isDirFS: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirFS),
                   isDirFS.boolValue
                {
                return true
                }
                return false
            }
            result = validDirectories.compactMap { buildFavTreeStructure(at: $0) }
        }
        
        return result
    }
}

    // MARK: - Sandbox Access
extension FavScanner {
    func requestAccessToVolumesDirectory(completion: @escaping (URL?) -> Void) {
        log.debug(#function)
        let openPanel = NSOpenPanel()
        openPanel.title = "Mimi: “Please select /Volumes"
        openPanel.allowsConcurrentViewDrawing = true
        openPanel.message = "Mimi: This is necessary to access mounted system volumes and favorites"
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        openPanel.directoryURL = URL(fileURLWithPath: "/Volumes")
        
        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                if selectedURL.startAccessingSecurityScopedResource() {
                    completion(selectedURL)
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }
}

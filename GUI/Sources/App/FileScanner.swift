//
// FileScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import Foundation

enum FileScanner {
    // MARK: - Scan directory contents
    static func scan(url: URL, showHiddenFiles: Bool = false) throws -> [CustomFile] {
        log.info("scan(url:) \(url.path), showHidden: \(showHiddenFiles)")
        var regularDirCount = 0
        var symlinkDirCount = 0
        var fileCount = 0
        var result: [CustomFile] = []
        let fileManager = FileManager.default

        let wantedKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        
        // Determine options based on showHiddenFiles setting
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: wantedKeys,
            options: options
        )
        for fileURL in contents {
            let values = try? fileURL.resourceValues(forKeys: Set(wantedKeys))
            let isDir = values?.isDirectory ?? false
            let isSymlink = values?.isSymbolicLink ?? false

            if isDir {
                if isSymlink {
                    symlinkDirCount += 1
                } else {
                    regularDirCount += 1
                }
            } else {
                fileCount += 1
            }

            let customFile = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
            result.append(customFile)
        }
        log.info("scan stats: dirs=\(regularDirCount), symlinkDirs=\(symlinkDirCount), files=\(fileCount)")
        return result
    }
}

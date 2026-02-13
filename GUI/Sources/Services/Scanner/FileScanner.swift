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
        log.info("⏳ scan START: \(url.path), showHidden: \(showHiddenFiles)")

        let fileManager = FileManager.default

        // Diagnostic: check path existence and readability
        let exists = fileManager.fileExists(atPath: url.path)
        let readable = fileManager.isReadableFile(atPath: url.path)
        log.info("📂 path exists: \(exists), readable: \(readable), scheme: \(url.scheme ?? "nil"), isFileURL: \(url.isFileURL)")

        if !exists {
            log.error("❌ scan ABORT: path does not exist: \(url.path)")
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
                          userInfo: [NSLocalizedDescriptionKey: "Path does not exist: \(url.path)"])
        }
        if !readable {
            log.error("🔒 scan ABORT: path not readable: \(url.path)")
            throw NSError(domain: NSPOSIXErrorDomain, code: 13,
                          userInfo: [NSLocalizedDescriptionKey: "Permission denied: \(url.path)"])
        }

        // Diagnostic: POSIX permissions
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
            let posix = attrs[.posixPermissions] as? Int ?? -1
            let owner = attrs[.ownerAccountName] as? String ?? "?"
            let group = attrs[.groupOwnerAccountName] as? String ?? "?"
            log.info("🔑 permissions: \(String(posix, radix: 8)), owner: \(owner), group: \(group)")
        }

        var regularDirCount = 0
        var symlinkDirCount = 0
        var fileCount = 0
        var result: [CustomFile] = []
        let wantedKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        // IMPORTANT: On /Volumes/* paths, macOS marks backup content with BSD UF_HIDDEN flag.
        // contentsOfDirectory with .skipsHiddenFiles skips these → empty listings.
        // Force showing all files for volume paths to avoid empty panels.
        let isVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
        let effectiveShowHidden = showHiddenFiles || isVolumePath
        if isVolumePath && !showHiddenFiles {
            log.info("🏷️ Volume path detected, forcing showHidden=true for \(url.path)")
        }
        let options: FileManager.DirectoryEnumerationOptions = effectiveShowHidden ? [] : [.skipsHiddenFiles]

        log.info("📋 calling contentsOfDirectory(at: \(url.path), options: \(options))")

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: wantedKeys,
                options: options
            )
        } catch {
            log.error("❌ contentsOfDirectory FAILED: \(error)")
            log.error("   NSError domain: \((error as NSError).domain), code: \((error as NSError).code)")
            if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                log.error("   underlying: domain=\(underlying.domain), code=\(underlying.code), desc=\(underlying.localizedDescription)")
            }
            throw error
        }

        log.info("📦 contentsOfDirectory returned \(contents.count) items")

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
        log.info("✅ scan DONE: dirs=\(regularDirCount), symlinkDirs=\(symlinkDirCount), files=\(fileCount), total=\(result.count)")
        return result
    }
}

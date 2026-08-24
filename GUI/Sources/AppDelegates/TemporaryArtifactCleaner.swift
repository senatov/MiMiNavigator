// TemporaryArtifactCleaner.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Removes only explicitly owned temporary artifacts while preserving logs and updater staging.

import Foundation

// MARK: - Temporary Artifact Cleaner
enum TemporaryArtifactCleaner {
    private static let exactTemporaryNames: Set<String> = [
        "MiMiFTP",
        "MiMiSMB",
        "MiMiSFTP",
        "MiMiNavigator_archives",
    ]
    private static let temporaryPrefixes = [
        "MiMiNav_nested_",
        "MiMiNav_tar_",
        "mimi_gif_",
        "mimi_tgs_",
    ]

    // MARK: - Cleanup
    static func cleanup(reason: String) async {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let temporaryRoot = fileManager.temporaryDirectory.standardizedFileURL
            let removedTemporaryCount = cleanupTemporaryRoot(temporaryRoot, fileManager: fileManager)
            let removedAtomicCount = cleanupAtomicStorageFiles(fileManager: fileManager)
            log.info(
                "[TempCleanup] reason=\(reason) removedTemporary=\(removedTemporaryCount) removedAtomic=\(removedAtomicCount) root='\(temporaryRoot.path)' logsPreserved=true updaterPreserved=true"
            )
        }.value
    }

    // MARK: - Temporary Root
    private static func cleanupTemporaryRoot(_ rootURL: URL, fileManager: FileManager) -> Int {
        guard let children = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) else { return 0 }
        var removedCount = 0
        for childURL in children where isOwnedTemporaryArtifact(childURL.lastPathComponent) {
            do {
                try fileManager.removeItem(at: childURL)
                removedCount += 1
                log.debug("[TempCleanup] removed '\(childURL.path)'")
            } catch {
                log.warning("[TempCleanup] failed path='\(childURL.path)' error='\(error.localizedDescription)'")
            }
        }
        return removedCount
    }

    // MARK: - Owned Artifact
    private static func isOwnedTemporaryArtifact(_ name: String) -> Bool {
        exactTemporaryNames.contains(name) || temporaryPrefixes.contains(where: name.hasPrefix)
    }

    // MARK: - Atomic Storage Files
    private static func cleanupAtomicStorageFiles(fileManager: FileManager) -> Int {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MiMiNavigator", isDirectory: true),
            let enumerator = fileManager.enumerator(
                at: applicationSupportURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
            )
        else { return 0 }
        var removedCount = 0
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if name == "Mounts", fileURL.deletingLastPathComponent().standardizedFileURL == applicationSupportURL.standardizedFileURL {
                enumerator.skipDescendants()
                continue
            }
            guard name.hasPrefix("."), name.contains(".tmp-") else { continue }
            do {
                try fileManager.removeItem(at: fileURL)
                removedCount += 1
                log.debug("[TempCleanup] removed atomic remainder '\(fileURL.path)'")
            } catch {
                log.warning("[TempCleanup] failed atomic path='\(fileURL.path)' error='\(error.localizedDescription)'")
            }
        }
        return removedCount
    }
}

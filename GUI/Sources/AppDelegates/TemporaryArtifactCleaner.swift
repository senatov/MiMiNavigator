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
        let artifacts = await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let roots = [
                fileManager.temporaryDirectory.standardizedFileURL,
                URL(fileURLWithPath: "/tmp", isDirectory: true).standardizedFileURL,
            ]
            let uniqueRoots = Dictionary(grouping: roots, by: \.path).compactMap(\.value.first)
            let temporaryURLs = uniqueRoots.flatMap {
                ownedTemporaryArtifacts(in: $0, fileManager: fileManager)
            }
            let atomicURLs = atomicStorageFiles(fileManager: fileManager)
            return (temporaryURLs, atomicURLs, uniqueRoots.map(\.path))
        }.value
        let removedTemporaryCount = await recycle(artifacts.0)
        let removedAtomicCount = await recycle(artifacts.1)
        log.info(
            "[TempCleanup] reason=\(reason) recycledTemporary=\(removedTemporaryCount) recycledAtomic=\(removedAtomicCount) roots='\(artifacts.2)' logsPreserved=true updaterPreserved=true"
        )
    }

    // MARK: - Temporary Root
    private static func ownedTemporaryArtifacts(in rootURL: URL, fileManager: FileManager) -> [URL] {
        guard let children = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) else { return [] }
        return children.filter { isOwnedTemporaryArtifact($0.lastPathComponent) }
    }

    // MARK: - Recycle
    @MainActor
    private static func recycle(_ urls: [URL]) async -> Int {
        var recycledCount = 0
        for url in urls {
            do {
                _ = try await FileRecycleService.recycle(url)
                recycledCount += 1
                log.debug("[TempCleanup] recycled '\(url.path)'")
            } catch {
                log.warning("[TempCleanup] recycle failed path='\(url.path)' error='\(error.localizedDescription)'")
            }
        }
        return recycledCount
    }

    // MARK: - Owned Artifact
    private static func isOwnedTemporaryArtifact(_ name: String) -> Bool {
        exactTemporaryNames.contains(name) || temporaryPrefixes.contains(where: name.hasPrefix)
    }

    // MARK: - Atomic Storage Files
    private static func atomicStorageFiles(fileManager: FileManager) -> [URL] {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MiMiNavigator", isDirectory: true),
            let enumerator = fileManager.enumerator(
                at: applicationSupportURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
            )
        else { return [] }
        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if name == "Mounts", fileURL.deletingLastPathComponent().standardizedFileURL == applicationSupportURL.standardizedFileURL {
                enumerator.skipDescendants()
                continue
            }
            guard name.hasPrefix("."), name.contains(".tmp-") else { continue }
            urls.append(fileURL)
        }
        return urls
    }
}

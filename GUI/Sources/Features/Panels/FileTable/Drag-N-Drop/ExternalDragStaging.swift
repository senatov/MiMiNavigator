// ExternalDragStaging.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Prepares remote files as local URLs for external drag destinations.

import Foundation
import FileModelKit

// MARK: - Remote Drag Entry
struct RemoteDragEntry: Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
}

// MARK: - External Drag Staging
enum ExternalDragStaging {
    @concurrent static func stage(
        _ entries: [RemoteDragEntry],
        provider: any RemoteFileProvider
    ) async throws -> [URL] {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
        cleanupStaleDirectories(in: root)
        let directory = root.appendingPathComponent("mimi-drag-url-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            var urls: [URL] = []
            for entry in entries {
                try Task.checkCancellation()
                let destination = directory.appendingPathComponent(entry.name, isDirectory: entry.isDirectory)
                try await provider.downloadToLocal(remotePath: entry.path, localPath: destination.path, recursive: entry.isDirectory)
                urls.append(destination)
            }
            try Task.checkCancellation()
            log.info("[DragExport] prepared \(urls.count) local file URL(s) for external drag")
            return urls
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    static func discard(_ urls: [URL]) {
        if let directory = urls.first?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func cleanupStaleDirectories(in root: URL) {
        let fileManager = FileManager.default
        let staleDate = Date().addingTimeInterval(-24 * 60 * 60)
        guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for entry in entries where entry.lastPathComponent.hasPrefix("mimi-drag-url-") {
            if let modified = try? entry.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modified < staleDate {
                try? fileManager.removeItem(at: entry)
            }
        }
    }
}

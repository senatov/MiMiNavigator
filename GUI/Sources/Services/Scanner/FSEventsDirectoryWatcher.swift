// FSEventsDirectoryWatcher.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Top-level directory change detection via FSEventStreamCreate.

import CoreServices
import FileModelKit
import Foundation

// MARK: - FSEvents Directory Watcher
final class FSEventsDirectoryWatcher: @unchecked Sendable {
    // MARK: - Directory Patch
    struct DirectoryPatch: Sendable {
        let childCountUpdates: [String: Int]
        let addedOrModified: [CustomFile]
        let removedPaths: [String]
        let watchedPath: String
        let needsFullRescan: Bool
    }

    // MARK: - Event Classification
    private struct EventClassification {
        var directChildren: [String] = []
        var childCountUpdates: [String: Int] = [:]
        var watchedDirectoryChanged = false
    }

    // MARK: - State
    private(set) var watchedPath = ""
    private var stream: FSEventStreamRef?
    private let callbackQueue = DispatchQueue(label: "mimi.fsevents", qos: .utility)
    private let onPatch: @Sendable (DirectoryPatch) -> Void
    private var showHiddenFiles = false
    private var pendingWork: DispatchWorkItem?
    private let throttleDelay: TimeInterval = 0.3
    private static let latency: CFTimeInterval = 0.5
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isAliasFileKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .fileSecurityKey,
        .directoryEntryCountKey,
        .creationDateKey,
        .contentAccessDateKey,
        .addedToDirectoryDateKey
    ]

    // MARK: - Init
    init(onPatch: @escaping @Sendable (DirectoryPatch) -> Void) {
        self.onPatch = onPatch
    }

    // MARK: - Watch
    @discardableResult
    func watch(path: String, showHiddenFiles: Bool) -> Bool {
        stop()
        guard !path.isEmpty else { return false }
        watchedPath = path
        self.showHiddenFiles = showHiddenFiles
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            guard let paths = cfPaths as? [String] else { return }
            watcher.scheduleHandleEvents(paths: paths)
        }
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagWatchRoot
        )
        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags
        ) else {
            log.error("[FSEvents] stream creation failed for '\(path)'")
            return false
        }
        FSEventStreamSetDispatchQueue(newStream, callbackQueue)
        guard FSEventStreamStart(newStream) else {
            FSEventStreamInvalidate(newStream)
            FSEventStreamRelease(newStream)
            log.error("[FSEvents] stream start failed for '\(path)'")
            return false
        }
        stream = newStream
        log.info("[FSEvents] watching '\(path)'")
        return true
    }

    // MARK: - Stop
    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        log.info("[FSEvents] stopped watching '\(watchedPath)'")
    }

    // MARK: - Schedule Event Handling
    private func scheduleHandleEvents(paths: [String]) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handleEvents(paths: paths)
        }
        pendingWork = work
        callbackQueue.asyncAfter(deadline: .now() + throttleDelay, execute: work)
    }

    // MARK: - Handle Events
    private func handleEvents(paths: [String]) {
        let watched = watchedPath
        var classification = classifyEvents(paths, watchedPath: watched)
        if classification.watchedDirectoryChanged && classification.directChildren.isEmpty {
            log.info("[FSEvents] watched directory changed; full rescan for '\(watched)'")
            onPatch(makeFullRescanPatch(watchedPath: watched, childCounts: classification.childCountUpdates))
            return
        }
        guard !classification.directChildren.isEmpty || !classification.childCountUpdates.isEmpty else { return }
        let changes = collectDirectChanges(
            classification.directChildren,
            childCounts: &classification.childCountUpdates
        )
        log.info("[FSEvents] \(classification.directChildren.count) item(s) changed in '\(watched)'")
        onPatch(DirectoryPatch(
            childCountUpdates: classification.childCountUpdates,
            addedOrModified: changes.added,
            removedPaths: changes.removed,
            watchedPath: watched,
            needsFullRescan: false
        ))
    }

    // MARK: - Classify Events
    private func classifyEvents(_ paths: [String], watchedPath: String) -> EventClassification {
        var result = EventClassification()
        for path in paths {
            let cleanPath = normalizedPath(path)
            if cleanPath == watchedPath {
                result.watchedDirectoryChanged = true
                continue
            }
            let parent = URL(fileURLWithPath: cleanPath).deletingLastPathComponent().path
            if parent == watchedPath {
                result.directChildren.append(cleanPath)
                continue
            }
            guard let subdirectoryPath = topLevelSubdirectoryPath(for: cleanPath, watchedPath: watchedPath),
                  result.childCountUpdates[subdirectoryPath] == nil,
                  let count = directoryEntryCount(at: subdirectoryPath)
            else {
                continue
            }
            result.childCountUpdates[subdirectoryPath] = count
        }
        return result
    }

    // MARK: - Collect Direct Changes
    private func collectDirectChanges(
        _ paths: [String],
        childCounts: inout [String: Int]
    ) -> (added: [CustomFile], removed: [String]) {
        var added: [CustomFile] = []
        var removed: [String] = []
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else {
                removed.append(path)
                continue
            }
            let url = URL(fileURLWithPath: path)
            if !showHiddenFiles && url.lastPathComponent.hasPrefix(".") { continue }
            if isDirectory(path), let count = directoryEntryCount(at: path) {
                childCounts[path] = count
            }
            if let file = makeCustomFile(url: url) {
                added.append(file)
            }
        }
        return (added, removed)
    }

    // MARK: - Make Custom File
    private func makeCustomFile(url: URL) -> CustomFile? {
        if let values = try? url.resourceValues(forKeys: Self.resourceKeys) {
            return CustomFile(url: url, resourceValues: values)
        }
        guard !isDirectory(url.path) else { return nil }
        return CustomFile(name: url.lastPathComponent, path: url.path)
    }

    // MARK: - Full Rescan Patch
    private func makeFullRescanPatch(
        watchedPath: String,
        childCounts: [String: Int]
    ) -> DirectoryPatch {
        DirectoryPatch(
            childCountUpdates: childCounts,
            addedOrModified: [],
            removedPaths: [],
            watchedPath: watchedPath,
            needsFullRescan: true
        )
    }

    // MARK: - Top-Level Subdirectory Path
    private func topLevelSubdirectoryPath(for path: String, watchedPath: String) -> String? {
        let prefix = watchedPath.hasSuffix("/") ? watchedPath : watchedPath + "/"
        guard path.hasPrefix(prefix) else { return nil }
        let relativePath = String(path.dropFirst(prefix.count))
        guard let separator = relativePath.firstIndex(of: "/") else { return nil }
        let name = String(relativePath[..<separator])
        return (watchedPath as NSString).appendingPathComponent(name)
    }

    // MARK: - Directory Entry Count
    private func directoryEntryCount(at path: String) -> Int? {
        let url = URL(fileURLWithPath: path)
        return try? url.resourceValues(forKeys: [.directoryEntryCountKey]).directoryEntryCount
    }

    // MARK: - Directory Check
    private func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    // MARK: - Normalize Path
    private func normalizedPath(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    deinit {
        stop()
    }
}

// FSEventsDirectoryWatcher.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Surgical directory change detection via FSEventStreamCreate (kernel-level).
//   Watches only the top-level directory (no kFSEventStreamCreateFlagFileEvents) —
//   that flag triggers recursive events from all subdirectories which floods the queue
//   on large collections like Anki media (26k files, constant writes).
//
// Strategy:
//   • Dir-level events only (no FileEvents flag) → one event per batch of changes
//   • Throttle: coalesce rapid bursts into a single callback via latency + DispatchWorkItem
//   • Filter: only events whose parent == watchedPath reach onPatch
//   • Sorting is done off MainActor before patch delivery

import CoreServices
import FileModelKit
import Foundation

// MARK: - FSEvents Directory Watcher

final class FSEventsDirectoryWatcher: @unchecked Sendable {

    // MARK: - Types

    struct DirectoryPatch: Sendable {
        let addedOrModified: [CustomFile]
        let removedPaths: [String]
        let watchedPath: String
    }

    // MARK: - State

    private(set) var watchedPath: String = ""
    private var stream: FSEventStreamRef?
    private let callbackQueue = DispatchQueue(label: "mimi.fsevents", qos: .utility)
    private let onPatch: @Sendable (DirectoryPatch) -> Void
    private var showHiddenFiles: Bool = false

    // Throttle: discard bursts — only process last event after quiet period
    private var pendingWork: DispatchWorkItem?
    private let throttleDelay: TimeInterval = 0.3

    // FSEvents kernel-side coalescing latency
    private static let latency: CFTimeInterval = 0.5

    // MARK: - Init

    init(onPatch: @escaping @Sendable (DirectoryPatch) -> Void) {
        self.onPatch = onPatch
    }

    // MARK: - Start / Stop

    func watch(path: String, showHiddenFiles: Bool) {
        stop()
        guard !path.isEmpty else { return }
        watchedPath = path
        self.showHiddenFiles = showHiddenFiles
        let pathsToWatch = [path] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: { ptr in
                if let p = ptr { Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(p).release() }
            },
            copyDescription: nil
        )
        // NOTE: NO kFSEventStreamCreateFlagFileEvents — that flag causes recursive subtree
        // events which floods the queue on directories with active subdirs (e.g. Anki media).
        // Dir-level events are sufficient: one event fires when anything in the dir changes.
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagNoDefer
        )
        let callback: FSEventStreamCallback = { _, infoPtr, numEvents, eventPaths, eventFlags, _ in
            guard let infoPtr else { return }
            let watcher = Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(infoPtr).takeUnretainedValue()
            let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            guard let rawPaths = cfPaths as? [String] else { return }
            let flagsArray = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
            watcher.scheduleHandleEvents(paths: rawPaths, flags: flagsArray)
        }
        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags
        ) else {
            log.error("[FSEvents] FSEventStreamCreate FAILED for '\(path)'")
            return
        }
        FSEventStreamSetDispatchQueue(s, callbackQueue)
        FSEventStreamStart(s)
        stream = s
        log.info("[FSEvents] watching '\(path)'")
    }

    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
        log.info("[FSEvents] stopped watching '\(watchedPath)'")
    }

    // MARK: - Throttle

    /// Coalesces rapid bursts: cancels previous work item, schedules new one after throttleDelay.
    private func scheduleHandleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handleEvents(paths: paths, flags: flags)
        }
        pendingWork = work
        callbackQueue.asyncAfter(deadline: .now() + throttleDelay, execute: work)
    }

    // MARK: - Event handling (runs on callbackQueue — NOT MainActor)

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        let watched = watchedPath
        // Keep only direct children of the watched directory
        let affectedPaths = paths.filter { p in
            URL(fileURLWithPath: p).deletingLastPathComponent().path == watched
        }
        guard !affectedPaths.isEmpty else {
            // Subdirectory event — irrelevant for panel display, skip silently
            return
        }
        log.info("[FSEvents] \(affectedPaths.count) item(s) changed in '\(watched)'")
        var added: [CustomFile] = []
        var removed: [String] = []
        let fm = FileManager.default
        let hidden = showHiddenFiles
        for p in affectedPaths {
            let url = URL(fileURLWithPath: p)
            if fm.fileExists(atPath: p) {
                if !hidden && url.lastPathComponent.hasPrefix(".") { continue }
                let keys: Set<URLResourceKey> = [
                    .isDirectoryKey, .isSymbolicLinkKey,
                    .fileSizeKey, .contentModificationDateKey, .fileSecurityKey,
                ]
                if let rv = try? url.resourceValues(forKeys: keys) {
                    var file = CustomFile(url: url, resourceValues: rv)
                    if file.isDirectory {
                        file.cachedChildCount = (try? fm.contentsOfDirectory(atPath: p).count) ?? 0
                    }
                    added.append(file)
                } else {
                    added.append(CustomFile(name: url.lastPathComponent, path: p))
                }
            } else {
                removed.append(p)
            }
        }
        let patch = DirectoryPatch(addedOrModified: added, removedPaths: removed, watchedPath: watched)
        log.debug("[FSEvents] patch — added: \(added.count) removed: \(removed.count)")
        onPatch(patch)
    }

    deinit { stop() }
}

// FSEventsDirectoryWatcher.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Surgical directory change detection via FSEventStreamCreate (kernel-level).
//   Unlike vnode DispatchSource (which fires once per open fd and requires a full rescan),
//   FSEvents delivers individual path-level events — only the changed file/subdirectory
//   is re-stat()ed, so the panel list is patched in-place without a full directory scan.
//
// Key advantages over vnode:
//   • Receives the exact changed path(s), not just "something changed"
//   • Coalesces rapid changes into a single callback (no custom throttle needed)
//   • Survives directory renames — FSEventStreamSetExclusionPaths is not needed
//   • Works on network volumes (AFP/SMB) where kqueue/vnode is unreliable
//
// Thread model:
//   Callback fires on a dedicated DispatchQueue → merges items on MainActor.

import CoreServices
import FileModelKit
import Foundation

// MARK: - FSEvents Directory Watcher

/// Watches a local directory with FSEvents and delivers incremental file list patches.
/// Replaces the vnode DispatchSource in DualDirectoryScanner for local paths.
final class FSEventsDirectoryWatcher: @unchecked Sendable {

    // MARK: - Types

    /// Patch delivered to the owner when the directory changes.
    struct DirectoryPatch: Sendable {
        let addedOrModified: [CustomFile]
        let removedPaths: [String]
        let watchedPath: String
    }

    // MARK: - Public state

    private(set) var watchedPath: String = ""

    // MARK: - Private state

    private var stream: FSEventStreamRef?
    private let callbackQueue = DispatchQueue(label: "mimi.fsevents", qos: .utility)
    private let onPatch: @Sendable (DirectoryPatch) -> Void
    private var showHiddenFiles: Bool = false

    // FSEvents coalescing — kernel delivers events ~0.15s after the last change in a burst
    private static let latency: CFTimeInterval = 0.15

    // MARK: - Init

    /// - Parameters:
    ///   - onPatch: Called on a background queue whenever the watched directory changes.
    ///             Dispatch to MainActor inside the closure to update AppState.
    init(onPatch: @escaping @Sendable (DirectoryPatch) -> Void) {
        self.onPatch = onPatch
    }

    // MARK: - Start / Stop

    /// Start watching `path`. Replaces any previous watch.
    func watch(path: String, showHiddenFiles: Bool) {
        stop()
        guard !path.isEmpty else { return }
        self.watchedPath = path
        self.showHiddenFiles = showHiddenFiles
        let pathsToWatch = [path] as CFArray
        // C callback — must capture self via context pointer
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: { ptr in
                if let p = ptr { Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(p).release() }
            },
            copyDescription: nil
        )
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents    // per-file events, not just dir-level
            | kFSEventStreamCreateFlagNoDefer       // deliver as soon as latency expires
        )
        let callback: FSEventStreamCallback = { _, infoPtr, numEvents, eventPaths, eventFlags, _ in
            guard let infoPtr else { return }
            let watcher = Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(infoPtr).takeUnretainedValue()
            // eventPaths is UnsafeMutableRawPointer; with kFSEventStreamCreateFlagUseCFTypes
            // it points to a CFArray of CFString — bridge via Unmanaged to avoid the bad cast.
            let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            guard let rawPaths = cfPaths as? [String] else { return }
            let flagsArray = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
            watcher.handleEvents(paths: rawPaths, flags: flagsArray)
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

    /// Stop watching. Safe to call when not watching.
    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
        log.info("[FSEvents] stopped watching '\(watchedPath)'")
    }

    // MARK: - Event handling

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        let watched = watchedPath
        // Filter to direct children only — we do NOT recursively rescan subdirectories
        let affectedPaths = paths.filter { p in
            let url = URL(fileURLWithPath: p)
            return url.deletingLastPathComponent().path == watched
        }
        guard !affectedPaths.isEmpty else {
            log.debug("[FSEvents] event outside watched dir — skipped")
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
                // File still exists — re-stat it and add to patch
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
                // File removed
                removed.append(p)
            }
        }
        let patch = DirectoryPatch(addedOrModified: added, removedPaths: removed, watchedPath: watched)
        log.debug("[FSEvents] patch — added/modified: \(added.count), removed: \(removed.count)")
        onPatch(patch)
    }

    // MARK: - Deinit

    deinit {
        stop()
    }
}

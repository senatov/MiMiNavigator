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
            // Paths with updated childCount (subdirectory changes)
            let childCountUpdates: [String: Int]
            let addedOrModified: [CustomFile]
            let removedPaths: [String]
            let watchedPath: String
            /// True when the watched directory itself was reported changed (dir-level event).
            /// Signals that a full rescan is needed because we cannot determine removals incrementally.
            let needsFullRescan: Bool
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

        // Full-rescan protection (avoid duplicate rescans from bursty FSEvents)
        private var lastFullRescanDate: Date?
        private let fullRescanMinInterval: TimeInterval = 1.0

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
            // kFSEventStreamCreateFlagNoDefer removed: it bypasses kernel-side batching
            // and causes 3x duplicate callbacks per event. latency=0.5s + throttle=0.3s suffice.
            let flags = UInt32(
                kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagWatchRoot
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
            //log.debug("[FSEvents] scheduleHandleEvents: \(paths.count) paths for '\(watchedPath)': \(paths)")
            let work = DispatchWorkItem { [weak self] in
                self?.handleEvents(paths: paths, flags: flags)
            }
            pendingWork = work
            callbackQueue.asyncAfter(deadline: .now() + throttleDelay, execute: work)
        }

        // MARK: - Event handling (runs on callbackQueue — NOT MainActor)
        private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
            let watched = watchedPath
            let fm = FileManager.default
            let hidden = showHiddenFiles
            var directChildren: [String] = []
            var childCountUpdates: [String: Int] = [:]

            var watchedDirChanged = false
            for p in paths {
                let cleanPath = p.hasSuffix("/") ? String(p.dropLast()) : p
                // Dir-level FSEvents (no kFSEventStreamCreateFlagFileEvents) returns
                // the watched directory path itself when any direct child changes.
                // Enumerate all current children to detect adds/removes.
                if cleanPath == watched {
                    watchedDirChanged = true
                    continue
                }
                let url = URL(fileURLWithPath: cleanPath)
                let parent = url.deletingLastPathComponent().path
                if parent == watched {
                    directChildren.append(p)
                } else {
                    let relPath = String(p.dropFirst(watched.count + 1))
                    if let firstSlash = relPath.firstIndex(of: "/") {
                        let subdirName = String(relPath[..<firstSlash])
                        let subdirPath = (watched as NSString).appendingPathComponent(subdirName)
                        if childCountUpdates[subdirPath] == nil {
                            // Avoid expensive directory scans during FSEvents handling.
                            // Use -1 to signal "child count changed, recompute lazily".
                            childCountUpdates[subdirPath] = -1
                        }
                    }
                }
            }
            // When dir-level event fires for watched dir itself, trigger full rescan.
            // Dir-level FSEvents cannot tell us which files were added/removed —
            // only that "something changed" in the directory.
            //log.debug("[FSEvents] handleEvents: watchedDirChanged=\(watchedDirChanged) directChildren=\(directChildren.count) childCountUpdates=\(childCountUpdates.count)")
            if watchedDirChanged && directChildren.isEmpty {
                let now = Date()
                if let last = lastFullRescanDate,
                   now.timeIntervalSince(last) < fullRescanMinInterval {
                    log.debug("[FSEvents] full rescan suppressed (debounced) for '\(watched)'")
                    return
                }

                lastFullRescanDate = now
                log.info("[FSEvents] watched dir event → full rescan for '\(watched)' (debounced)")

                let patch = DirectoryPatch(
                    childCountUpdates: childCountUpdates,
                    addedOrModified: [],
                    removedPaths: [],
                    watchedPath: watched,
                    needsFullRescan: true
                )
                onPatch(patch)
                return
            }
            guard !directChildren.isEmpty || !childCountUpdates.isEmpty else { return }

            var added: [CustomFile] = []
            var removed: [String] = []

            for p in directChildren {
                let cleanPath = p.hasSuffix("/") ? String(p.dropLast()) : p

                // Skip if this is the watched directory itself
                if cleanPath == watched { continue }
                let url = URL(fileURLWithPath: cleanPath)
                if fm.fileExists(atPath: cleanPath) {
                    if !hidden && url.lastPathComponent.hasPrefix(".") { continue }
                    // For existing directories: dir-level FSEvents fires when contents change,
                    // NOT when the directory itself was added. Only update childCount.
                    var isDirFlag = ObjCBool(false)
                    _ = fm.fileExists(atPath: cleanPath, isDirectory: &isDirFlag)
                    if isDirFlag.boolValue {
                        // Do not scan directory contents here (can be very expensive on bursts of events).
                        // Mark child count as unknown; UI can recompute lazily if needed.
                        childCountUpdates[cleanPath] = -1
                        // Still create/update the CustomFile entry for genuine adds
                        // but only if this is flagged as a new item (not already in the list).
                        // Since we can't check the existing list here (we're off MainActor),
                        // always include it — applyPatch will merge by pathStr.
                        let keys: Set<URLResourceKey> = [
                            .isDirectoryKey, .isSymbolicLinkKey,
                            .fileSizeKey, .contentModificationDateKey, .fileSecurityKey,
                        ]
                        if let rv = try? url.resourceValues(forKeys: keys) {
                            var file = CustomFile(url: url, resourceValues: rv)
                            // Avoid directory enumeration during event handling
                            file.cachedChildCount = -1
                            added.append(file)
                        }
                    } else {
                        let keys: Set<URLResourceKey> = [
                            .isDirectoryKey, .isSymbolicLinkKey,
                            .fileSizeKey, .contentModificationDateKey, .fileSecurityKey,
                        ]
                        if let rv = try? url.resourceValues(forKeys: keys) {
                            added.append(CustomFile(url: url, resourceValues: rv))
                        } else {
                            added.append(CustomFile(name: url.lastPathComponent, path: cleanPath))
                        }
                    }
                } else {
                    removed.append(cleanPath)
                }
            }

            if !directChildren.isEmpty {
                log.info("[FSEvents] \(directChildren.count) item(s) changed in '\(watched)'")
            }
            if !childCountUpdates.isEmpty {
            }

            let patch = DirectoryPatch(
                childCountUpdates: childCountUpdates,
                addedOrModified: added,
                removedPaths: removed,
                watchedPath: watched,
                needsFullRescan: false
            )
            onPatch(patch)
        }

        deinit { stop() }
    }

// JunkFinderModel.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - Cleanup Model
@MainActor
@Observable
final class JunkFinderModel {
    static let shared = JunkFinderModel()
    private(set) var candidates: [JunkCandidate] = []
    private(set) var visited = 0
    private(set) var isScanning = false
    private(set) var scanSucceeded = false
    private(set) var status = "Choose a folder to inspect. Scanning starts when MiMiNavigator is in the background."
    var selectedIDs: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var scanRoot: URL?
    private var generation = 0
    private init() {}

    // MARK: - Preferred Scope
    var preferredScope: String? {
        if let scanRoot { return scanRoot.path }
        guard let saved = MiMiDefaults.shared.string(forKey: "findFiles.cleanup.lastRoot"),
              JunkScanEngine.isSafeRoot(saved),
              FileManager.default.fileExists(atPath: saved) else { return nil }
        return saved
    }

    // MARK: - Start
    func start(path: String, automatic: Bool = false) {
        let expanded = (path as NSString).expandingTildeInPath
        let root = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        if automatic && scanRoot?.path == root.path { return }
        guard JunkScanEngine.isSafeRoot(root.path) else {
            status = JunkScanError.unsafeLocation.localizedDescription
            return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            status = JunkScanError.unreadableLocation.localizedDescription
            return
        }
        stop()
        generation += 1
        let currentGeneration = generation
        scanRoot = root
        MiMiDefaults.shared.set(root.path, forKey: "findFiles.cleanup.lastRoot")
        candidates = []
        selectedIDs = []
        visited = 0
        isScanning = true
        scanSucceeded = false
        status = "Waiting for low system load and for MiMiNavigator to leave the foreground…"
        let receiver = self
        scanTask = Task.detached(priority: .background) {
            do {
                let saved = await JunkScanDatabase.shared.loadSnapshot(root: root)
                await receiver.restore(saved, generation: currentGeneration)
                try await JunkScanEngine.scan(root: root) { progress in
                    await receiver.receive(progress, generation: currentGeneration)
                }
                await receiver.finish(generation: currentGeneration, error: nil)
            } catch is CancellationError {
                await receiver.finish(generation: currentGeneration, error: nil)
            } catch {
                await receiver.finish(generation: currentGeneration, error: error.localizedDescription)
            }
        }
        log.info("[Cleanup] Queued background scan: \(root.path)")
    }

    // MARK: - Restore Snapshot
    private func restore(_ saved: [JunkCandidate], generation: Int) {
        guard self.generation == generation, !saved.isEmpty else { return }
        candidates = prune(saved)
        status = "Showing \(candidates.count) saved candidates while the next idle scan is pending."
    }

    // MARK: - Stop
    func stop() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning { status = "Scan stopped after \(visited) items." }
        isScanning = false
        scanSucceeded = false
        generation += 1
    }

    // MARK: - Receive
    private func receive(_ progress: JunkScanProgress, generation: Int) {
        guard self.generation == generation else { return }
        visited = progress.visited
        candidates = progress.candidates.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.url.path < rhs.url.path
        }
        status = "Inspected \(visited) items. Pauses while MiMiNavigator is active or the system is busy."
    }

    // MARK: - Finish
    private func finish(generation: Int, error: String?) {
        guard self.generation == generation else { return }
        scanTask = nil
        isScanning = false
        scanSucceeded = error == nil
        status = error ?? "Scan complete: \(candidates.count) candidates in \(visited) items. Review before deleting."
        log.info("[Cleanup] \(status)")
    }

    // MARK: - Prune Removed Candidates
    private func prune(_ items: [JunkCandidate]) -> [JunkCandidate] {
        let existing = items.filter { FileManager.default.fileExists(atPath: $0.id) }
        let groupCounts = Dictionary(grouping: existing.compactMap(\.group), by: { $0 }).mapValues(\.count)
        return existing.filter { $0.group == nil || (groupCounts[$0.group!] ?? 0) > 1 }
    }

    // MARK: - Group Selection
    func selectGroup(_ group: String) {
        let members = candidates.filter { $0.group == group }.sorted { $0.url.path < $1.url.path }
        guard members.count > 1 else { return }
        let deletable = Set(members.dropFirst().map(\.id))
        if deletable.isSubset(of: selectedIDs) { selectedIDs.subtract(deletable) }
        else { selectedIDs.formUnion(deletable) }
    }

    // MARK: - Trash Selection
    func trashSelection() {
        let chosen = candidates.filter { selectedIDs.contains($0.id) }
        guard !chosen.isEmpty, scanSucceeded, let root = scanRoot else { return }
        let groups = Dictionary(grouping: candidates.compactMap { candidate -> JunkCandidate? in
            candidate.group == nil ? nil : candidate
        }, by: { $0.group! })
        let chosenPaths = Set(chosen.map(\.id))
        func isCovered(_ path: String) -> Bool {
            chosenPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
        for members in groups.values where members.contains(where: { isCovered($0.id) }) {
            guard members.contains(where: { !isCovered($0.id) && FileManager.default.fileExists(atPath: $0.url.path) }) else {
                status = "Keep at least one existing file in each duplicate group."
                return
            }
        }
        let topLevel = chosen.filter { candidate in
            !chosenPaths.contains(where: { $0 != candidate.id && candidate.id.hasPrefix($0 + "/") })
        }
        let paths = topLevel.prefix(8).map { "• \($0.url.path)" }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "Move \(topLevel.count) selected item\(topLevel.count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "These are candidates, not guaranteed disposable files. Review the paths:\n\n\(paths)\(topLevel.count > 8 ? "\n…and more" : "")"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let urls = topLevel.map(\.url).filter { url in
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(root.path + "/"), !JunkScanEngine.shouldExclude(path) else { return false }
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
        guard urls.count == topLevel.count else {
            status = "Some items changed since the scan. Scan again before moving them to Trash."
            return
        }
        Task {
            do {
                try await FindFilesOperationService.shared.execute(urls: urls, operation: .trash)
                candidates = prune(candidates)
                selectedIDs = selectedIDs.intersection(Set(candidates.map(\.id)))
                status = "Moved \(urls.count) items to Trash."
                await JunkScanDatabase.shared.saveSnapshot(candidates, root: root)
            } catch {
                status = "Could not move the selection to Trash: \(error.localizedDescription)"
                log.error("[Cleanup] Trash failed: \(error.localizedDescription)")
            }
        }
    }
}

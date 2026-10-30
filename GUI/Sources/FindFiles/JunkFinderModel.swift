// JunkFinderModel.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation
import FindFilesKit

// MARK: - Cleanup Model
@MainActor
@Observable
final class JunkFinderModel {
    static let shared = JunkFinderModel()
    private(set) var candidates: [JunkCandidate] = []
    private(set) var visited = 0
    private(set) var isScanning = false
    private(set) var isTrashing = false
    private(set) var status = "Automatic scan starts when MiMiNavigator is in the background and the Mac is idle."
    var selectedIDs: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var rootCandidates: [String: [JunkCandidate]] = [:]
    private var generation = 0
    private init() {}

    // MARK: - Start Automatic Scan
    func startAutomatic() {
        guard scanTask == nil else { return }
        generation += 1
        let currentGeneration = generation
        isScanning = true
        status = "Waiting for low system load and for MiMiNavigator to leave the foreground…"
        let receiver = self
        scanTask = Task.detached(priority: .background) {
            let roots = JunkScanScope.roots().filter { JunkScanEngine.isSafeRoot($0.path) }
            for root in roots {
                let saved = await JunkScanDatabase.shared.loadSnapshot(root: root)
                let partial = await JunkScanDatabase.shared.traversalCandidates(root: root)
                await receiver.restore(saved + partial, root: root, generation: currentGeneration)
            }
            let global = await JunkScanDatabase.shared.loadGlobalCandidates()
            await receiver.restoreGlobal(global, generation: currentGeneration)
            while !Task.isCancelled {
                for root in JunkScanScope.roots() where JunkScanEngine.isSafeRoot(root.path) {
                    do {
                        try await JunkScanEngine.scan(root: root) { progress in
                            await receiver.receive(progress, root: root, generation: currentGeneration)
                        }
                        let latest = await JunkScanDatabase.shared.loadSnapshot(root: root)
                        await receiver.completed(latest, root: root, generation: currentGeneration)
                    } catch is CancellationError {
                        return
                    } catch {
                        await receiver.scanError(error.localizedDescription, root: root, generation: currentGeneration)
                    }
                }
                do {
                    let global = try await JunkScanEngine.scanGlobalDuplicates()
                    await receiver.restoreGlobal(global, generation: currentGeneration)
                } catch is CancellationError {
                    return
                } catch {
                    await receiver.scanError(error.localizedDescription, root: URL(fileURLWithPath: "/Volumes"), generation: currentGeneration)
                }
                try? await Task.sleep(for: .seconds(21_600))
            }
        }
        log.info("[Cleanup] Automatic background scan queued")
    }

    // MARK: - Restore Snapshot
    private func restore(_ saved: [JunkCandidate], root: URL, generation: Int) {
        guard self.generation == generation, !saved.isEmpty else { return }
        rootCandidates[root.path] = prune(Array(Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest }).values))
        rebuildCandidates()
        status = "Showing \(candidates.count) saved candidates while the next idle scan is pending."
    }

    // MARK: - Restore Cross-Volume Groups
    private func restoreGlobal(_ saved: [JunkCandidate], generation: Int) {
        guard self.generation == generation else { return }
        rootCandidates["global"] = prune(saved)
        rebuildCandidates()
    }

    // MARK: - Stop
    func stop() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning { status = "Automatic scan paused after \(visited) items." }
        isScanning = false
        generation += 1
    }

    // MARK: - Receive
    private func receive(_ progress: JunkScanProgress, root: URL, generation: Int) {
        guard self.generation == generation else { return }
        visited = progress.visited
        let existing = rootCandidates[root.path] ?? []
        rootCandidates[root.path] = prune(Array(Dictionary((existing + progress.candidates).map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest }).values))
        rebuildCandidates()
        status = "Inspected \(visited) items in \(root.lastPathComponent). Pauses while the app is active or the system is busy."
    }

    // MARK: - Rebuild Candidate List
    private func rebuildCandidates() {
        let unique = Dictionary(rootCandidates.values.flatMap { $0 }.map { ($0.id, $0) }, uniquingKeysWith: { old, new in
            new.reason.contains("across local volumes") ? new : old
        })
        candidates = unique.values.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.url.path < rhs.url.path
        }
    }

    // MARK: - Completed Root
    private func completed(_ latest: [JunkCandidate], root: URL, generation: Int) {
        guard self.generation == generation else { return }
        rootCandidates[root.path] = prune(latest)
        rebuildCandidates()
        status = "Scanned \(root.lastPathComponent): \(candidates.count) accumulated candidates. Automatic review continues in the background."
        log.info("[Cleanup] \(status)")
    }

    // MARK: - Scan Error
    private func scanError(_ error: String, root: URL, generation: Int) {
        guard self.generation == generation else { return }
        status = "Could not inspect \(root.path): \(error)"
        log.warning("[Cleanup] \(status)")
    }

    // MARK: - Prune Removed Candidates
    private func prune(_ items: [JunkCandidate]) -> [JunkCandidate] {
        let existing = Dictionary(items.filter {
            FileManager.default.fileExists(atPath: $0.id) &&
                ($0.kind == .appLeftover || $0.kind == .processArtifact || !JunkScanEngine.shouldExclude($0.id)) &&
                ($0.kind != .emptyFolder || JunkScanEngine.isEligibleEmptyFolder($0.url))
        }.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest }).values
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
        guard !chosen.isEmpty, !isTrashing else { return }
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
        let urls = topLevel.filter { isAllowed(candidate: $0) }.map(\.url).filter { url in
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        guard urls.count == topLevel.count else {
            status = "Some items changed since the scan. Scan again before moving them to Trash."
            return
        }
        isTrashing = true
        Task {
            defer { isTrashing = false }
            do {
                for candidate in topLevel where !(await JunkScanEngine.stillMatchesCandidate(candidate)) {
                    status = "An item changed since the scan. Nothing was moved to Trash."
                    return
                }
                for members in groups.values where members.contains(where: { isCovered($0.id) }) {
                    let selected = members.filter { isCovered($0.id) }
                    let retained = members.filter { !isCovered($0.id) }
                    for candidate in selected where !(await JunkScanEngine.stillMatchesDuplicate(candidate)) {
                        status = "A duplicate changed since the scan. Wait for the next automatic review."
                        return
                    }
                    var matchingCopyRemains = false
                    for candidate in retained where !matchingCopyRemains {
                        matchingCopyRemains = await JunkScanEngine.stillMatchesDuplicate(candidate)
                    }
                    guard matchingCopyRemains else {
                        status = "No verified matching copy remains. Nothing was moved to Trash."
                        return
                    }
                }
                try await FindFilesOperationService.shared.execute(urls: urls, operation: .trash)
                status = "Moved \(urls.count) items to Trash."
                for root in JunkScanScope.roots() {
                    rootCandidates[root.path] = prune(rootCandidates[root.path] ?? [])
                    await JunkScanDatabase.shared.saveSnapshot(rootCandidates[root.path] ?? [], root: root)
                }
                rootCandidates["global"] = prune(rootCandidates["global"] ?? [])
                await JunkScanDatabase.shared.saveGlobalCandidates(rootCandidates["global"] ?? [])
                rebuildCandidates()
                selectedIDs = selectedIDs.intersection(Set(candidates.map(\.id)))
            } catch {
                status = "Could not move the selection to Trash: \(error.localizedDescription)"
                log.error("[Cleanup] Trash failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Candidate Safety
    private func isAllowed(candidate: JunkCandidate) -> Bool {
        let path = candidate.url.standardizedFileURL.path
        if candidate.kind == .appLeftover {
            let directChild = FindFilesLeftoverSafety.searchDirectories.contains {
                path == $0.appendingPathComponent(candidate.url.lastPathComponent).path
            }
            let installed = FindFilesLeftoverSafety.installedApplicationIdentities()
            return directChild && FindFilesLeftoverSafety.isCandidate(candidate.url, installedIdentities: installed)
        }
        if candidate.kind == .processArtifact {
            let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs", isDirectory: true)
            return candidate.url.deletingLastPathComponent().standardizedFileURL == logs.standardizedFileURL
        }
        return JunkScanScope.roots().contains { path.hasPrefix($0.path + "/") } && !JunkScanEngine.shouldExclude(path)
    }
}

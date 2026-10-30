// JunkScanEngine.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import CryptoKit
import Darwin
import Foundation
import FindFilesKit

// MARK: - Cleanup Candidate
struct JunkCandidate: Identifiable, Sendable, Codable {
    enum Kind: String, Sendable, Codable {
        case duplicate = "Duplicate"
        case duplicateFolder = "Duplicate folder"
        case emptyFolder = "Empty folder"
        case oldInstaller = "Old installer"
        case temporary = "Temporary file"
        case appLeftover = "App leftover"
    }
    let url: URL
    let kind: Kind
    let reason: String
    let size: Int64
    let group: String?
    var id: String { url.path }
}

// MARK: - Scan Progress
struct JunkScanProgress: Sendable {
    let visited: Int
    let candidates: [JunkCandidate]
}

// MARK: - Idle Cleanup Scanner
enum JunkScanEngine {
    private struct FileRecord: Sendable {
        let url: URL
        let size: Int64
        let modified: Date
    }

    // MARK: - Scan
    static func scan(root: URL, update: @escaping @Sendable (JunkScanProgress) async -> Void) async throws {
        let rootPath = root.standardizedFileURL.path
        guard isSafeRoot(rootPath) else { throw JunkScanError.unsafeLocation }
        var files: [FileRecord] = []
        var directories: [URL] = []
        var candidates: [JunkCandidate] = []
        var visited = 0
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in
            log.warning("[Cleanup] Cannot inspect \(url.path): \(error.localizedDescription)")
            return true
        }) else { throw JunkScanError.unreadableLocation }
        try await waitForIdle()
        while let url = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            if visited % 64 == 0 { try await waitForIdle() }
            let path = url.standardizedFileURL.path
            if shouldExclude(path) { enumerator.skipDescendants(); continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true, values.isUbiquitousItem != true else { continue }
            visited += 1
            if values.isDirectory == true {
                if isEmptyDirectory(url) {
                    candidates.append(JunkCandidate(url: url, kind: .emptyFolder, reason: "Directory contains no files", size: 0, group: nil))
                } else {
                    directories.append(url)
                }
            } else if values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                let modified = values.contentModificationDate ?? .now
                files.append(FileRecord(url: url, size: size, modified: modified))
                if let kind = staleFileKind(url: url, modified: modified) {
                    candidates.append(JunkCandidate(url: url, kind: kind, reason: kind == .oldInstaller ? "Installer older than 90 days" : "Temporary file older than 30 days", size: size, group: nil))
                }
            }
            if visited % 256 == 0 { await update(JunkScanProgress(visited: visited, candidates: candidates)) }
            if visited % 4096 == 0 { await JunkScanDatabase.shared.saveSnapshot(candidates, root: root) }
        }
        let sameSize = Dictionary(grouping: files.filter { $0.size > 0 }, by: \.size).values.filter { $0.count > 1 }
        var hashes: [String: [FileRecord]] = [:]
        for group in sameSize {
            for file in group {
                try Task.checkCancellation()
                try await waitForIdle()
                guard isUnchanged(file.url, size: file.size, modified: file.modified) else { continue }
                let digest: String
                if let cached = await JunkScanDatabase.shared.digest(for: file.url, size: file.size, modified: file.modified) {
                    digest = cached
                } else {
                    guard let computed = try? await hash(file.url) else { continue }
                    digest = computed
                    await JunkScanDatabase.shared.saveDigest(digest, for: file.url, size: file.size, modified: file.modified)
                }
                guard isUnchanged(file.url, size: file.size, modified: file.modified) else { continue }
                hashes["\(file.size):\(digest)", default: []].append(file)
            }
        }
        for (group, records) in hashes where records.count > 1 {
            let paths = Set(records.map { $0.url.path })
            candidates.removeAll { paths.contains($0.url.path) }
            for file in records.sorted(by: { $0.url.path < $1.url.path }) {
                candidates.append(JunkCandidate(url: file.url, kind: .duplicate, reason: "Exact content match in \(records.count) files; keep at least one copy", size: file.size, group: group))
            }
        }
        var folderGroups: [String: [(URL, Int64)]] = [:]
        for directory in directories {
            try Task.checkCancellation()
            try await waitForIdle()
            guard let signature = await leafFolderSignature(directory) else { continue }
            folderGroups[signature.0, default: []].append((directory, signature.1))
        }
        for (signature, folders) in folderGroups where folders.count > 1 {
            for (url, size) in folders {
                candidates.append(JunkCandidate(url: url, kind: .duplicateFolder, reason: "Exact names and contents match in \(folders.count) folders; keep at least one", size: size, group: "folder:\(signature)"))
            }
        }
        if rootPath == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path {
            try await inspectApplicationLeftovers(into: &candidates)
        }
        await JunkScanDatabase.shared.saveSnapshot(candidates, root: root)
        await update(JunkScanProgress(visited: visited, candidates: candidates))
    }

    // MARK: - Idle Gate
    static func waitForIdle() async throws {
        var attempts = 0
        while !Task.isCancelled {
            let inactive = await MainActor.run {
                NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
            var loads = [Double](repeating: 0, count: 3)
            let measured = getloadavg(&loads, 3) > 0
            let cores = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
            let thermal = ProcessInfo.processInfo.thermalState
            if inactive && measured && loads[0] < cores * 0.5 && thermal == .nominal { return }
            if attempts.isMultiple(of: 6) {
                log.debug("[Cleanup] Waiting: inactive=\(inactive) load=\(loads[0]) cores=\(cores) thermal=\(thermal.rawValue)")
            }
            attempts += 1
            try? await Task.sleep(for: .seconds(5))
        }
        throw CancellationError()
    }

    // MARK: - Safety Rules
    static func isSafeRoot(_ path: String) -> Bool {
        let resolved = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if (resolved == home || resolved.hasPrefix(home + "/")) && !shouldExclude(resolved) { return true }
        return JunkScanScope.localVolumes().contains { resolved == $0.path } && !shouldExclude(resolved)
    }

    static func shouldExclude(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let excluded = ["/Library", "/.Trash", "/.git", "/.build", "/node_modules", "/.swiftpm", "/Applications", "/System"]
        if path.contains("/Library/CloudStorage/") || path.hasSuffix("/Library/CloudStorage") { return true }
        return excluded.contains { suffix in path == home + suffix || path.hasPrefix(home + suffix + "/") || path.contains(suffix + "/") }
    }

    // MARK: - Possible Application Leftovers
    private static func inspectApplicationLeftovers(into candidates: inout [JunkCandidate]) async throws {
        guard JunkAIReviewer.isAvailable else { return }
        let installed = FindFilesLeftoverSafety.installedApplicationIdentities()
        let running = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        }
        var newReviews = 0
        for directory in FindFilesLeftoverSafety.searchDirectories {
            guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .contentModificationDateKey]) else { continue }
            for child in children {
                try Task.checkCancellation()
                let name = child.lastPathComponent.lowercased()
                guard !name.hasPrefix("."), name.contains("."),
                      !name.hasPrefix("com.apple."), !name.hasPrefix("group.com.apple."),
                      FindFilesLeftoverSafety.isCandidate(child, installedIdentities: installed),
                      !running.contains(where: { name.contains($0) }),
                      let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey]),
                      values.isSymbolicLink != true,
                      let modified = values.contentModificationDate,
                      Date().timeIntervalSince(modified) > 180 * 86400 else { continue }
                let recommended: Bool
                if let cached = await JunkScanDatabase.shared.aiReview(for: child, modified: modified) {
                    recommended = cached
                } else {
                    guard newReviews < 40 else { continue }
                    try await waitForIdle()
                    guard let review = await JunkAIReviewer.review(child, category: directory.lastPathComponent) else { continue }
                    recommended = review
                    await JunkScanDatabase.shared.saveAIReview(review, for: child, modified: modified)
                    newReviews += 1
                }
                guard recommended else { continue }
                let reason = "Possible leftover from an uninstalled app; on-device AI recommends review"
                candidates.append(JunkCandidate(url: child, kind: .appLeftover, reason: reason, size: 0, group: nil))
            }
        }
    }

    private static func isEmptyDirectory(_ url: URL) -> Bool {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return items.isEmpty
    }

    private static func staleFileKind(url: URL, modified: Date) -> JunkCandidate.Kind? {
        let age = Date().timeIntervalSince(modified)
        let ext = url.pathExtension.lowercased()
        if age > 90 * 86400 && ["dmg", "pkg", "xip"].contains(ext) { return .oldInstaller }
        if age > 30 * 86400 && ["tmp", "temp", "part"].contains(ext) { return .temporary }
        return nil
    }

    // MARK: - Leaf Folder Signature
    private static func leafFolderSignature(_ directory: URL) async -> (String, Int64)? {
        guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
              !children.isEmpty, children.count <= 100 else { return nil }
        var total: Int64 = 0
        var hasher = SHA256()
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
            let size = Int64(values.fileSize ?? 0)
            total += size
            if total > 1_073_741_824 { return nil }
            let modified = values.contentModificationDate ?? .now
            let digest: String
            if let cached = await JunkScanDatabase.shared.digest(for: child, size: size, modified: modified) {
                digest = cached
            } else {
                guard let computed = try? await hash(child) else { return nil }
                digest = computed
                await JunkScanDatabase.shared.saveDigest(digest, for: child, size: size, modified: modified)
            }
            guard isUnchanged(child, size: size, modified: modified) else { return nil }
            hasher.update(data: Data("\(child.lastPathComponent):\(size):\(digest)\n".utf8))
        }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), total)
    }

    // MARK: - Verify File Metadata
    private static func isUnchanged(_ url: URL, size: Int64, modified: Date) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
              values.isRegularFile == true else { return false }
        return Int64(values.fileSize ?? -1) == size && values.contentModificationDate == modified
    }

    private static func hash(_ url: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var chunks = 0
        while true {
            if chunks.isMultiple(of: 8) { try await waitForIdle() }
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
            chunks += 1
            try Task.checkCancellation()
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Scan Error
enum JunkScanError: LocalizedError {
    case unsafeLocation
    case unreadableLocation
    var errorDescription: String? {
        switch self {
        case .unsafeLocation: "Choose a local folder inside your home directory. System and cloud folders are excluded."
        case .unreadableLocation: "The selected folder cannot be read."
        }
    }
}

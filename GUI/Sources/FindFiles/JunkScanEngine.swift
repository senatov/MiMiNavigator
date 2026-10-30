// JunkScanEngine.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import CryptoKit
import Darwin
import Foundation

// MARK: - Cleanup Candidate
struct JunkCandidate: Identifiable, Sendable, Codable {
    enum Kind: String, Sendable, Codable {
        case duplicate = "Duplicate"
        case duplicateFolder = "Duplicate folder"
        case emptyFolder = "Empty folder"
        case oldInstaller = "Old installer"
        case temporary = "Temporary file"
        case appLeftover = "App leftover"
        case processArtifact = "Stale process file"
    }
    let url: URL
    let kind: Kind
    let reason: String
    let size: Int64
    let group: String?
    var modified: Date? = nil
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var location: String { url.deletingLastPathComponent().path }
    var sortableDate: Date { modified ?? .distantPast }
}

// MARK: - Scan Progress
struct JunkScanProgress: Sendable {
    let visited: Int
    let candidates: [JunkCandidate]
}

// MARK: - Persistent Traversal Record
struct JunkFileRecord: Sendable {
    let url: URL
    let size: Int64
    let modified: Date
}

// MARK: - Directory Checkpoint
struct JunkDirectoryBatch: Sendable {
    let directory: URL
    let childDirectories: [URL]
    let files: [JunkFileRecord]
    let candidates: [JunkCandidate]
    let visited: Int
}

// MARK: - Idle Cleanup Scanner
enum JunkScanEngine {
    nonisolated(unsafe) private static let developmentCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 20_000
        return cache
    }()
    // MARK: - Scan
    static func scan(root: URL, update: @escaping @Sendable (JunkScanProgress) async -> Void) async throws {
        let rootPath = root.standardizedFileURL.path
        guard isSafeRoot(rootPath) else { throw JunkScanError.unsafeLocation }
        let database = JunkScanDatabase.shared
        var visited = try await database.beginTraversal(root: root)
        try await waitForIdle()
        while let directory = await database.nextDirectory(root: root) {
            try Task.checkCancellation()
            try await waitForIdle()
            let batch = try await inspectDirectory(directory)
            guard await database.saveDirectory(batch, root: root) else { throw JunkScanError.unreadableLocation }
            visited += batch.visited
            if visited % 256 < batch.visited {
                let partial = await database.traversalCandidates(root: root)
                await update(JunkScanProgress(visited: visited, candidates: partial))
            }
        }
        let traversal = await database.traversalData(root: root)
        let files = traversal.files
        let directories = traversal.directories
        var candidates = traversal.candidates
        let sameSize = Dictionary(grouping: files.filter { $0.size > 0 }, by: \.size).values.filter { $0.count > 1 }
        var hashes: [String: [JunkFileRecord]] = [:]
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
                candidates.append(JunkCandidate(url: file.url, kind: .duplicate, reason: "Exact content match in \(records.count) files; keep at least one copy", size: file.size, group: group, modified: file.modified))
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
                candidates.append(JunkCandidate(url: url, kind: .duplicateFolder, reason: "Exact names and contents match in \(folders.count) folders; keep at least one", size: size, group: "folder:\(signature)", modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate))
            }
        }
        if rootPath == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path {
            try await inspectStaleProcessArtifacts(into: &candidates)
            try await inspectApplicationLeftovers(into: &candidates)
        }
        await JunkScanDatabase.shared.saveSnapshot(candidates, root: root)
        try await JunkScanDatabase.shared.finishTraversal(root: root)
        await update(JunkScanProgress(visited: visited, candidates: candidates))
    }

    // MARK: - Inspect One Directory
    private static func inspectDirectory(_ directory: URL) async throws -> JunkDirectoryBatch {
        if shouldExclude(directory.standardizedFileURL.path) {
            return JunkDirectoryBatch(directory: directory, childDirectories: [], files: [], candidates: [], visited: 0)
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey]
        guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            log.warning("[Cleanup] Cannot inspect \(directory.path)")
            return JunkDirectoryBatch(directory: directory, childDirectories: [], files: [], candidates: [], visited: 0)
        }
        var childDirectories: [URL] = []
        var files: [JunkFileRecord] = []
        var candidates: [JunkCandidate] = []
        var visited = 0
        for url in children {
            try Task.checkCancellation()
            if visited.isMultiple(of: 64) { try await waitForIdle() }
            let path = url.standardizedFileURL.path
            guard !shouldExclude(path),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true, values.isUbiquitousItem != true else { continue }
            visited += 1
            if values.isDirectory == true {
                guard values.isPackage != true else { continue }
                if isEligibleEmptyFolder(url) {
                    candidates.append(JunkCandidate(url: url, kind: .emptyFolder, reason: "Directory has been empty for over 90 days", size: 0, group: nil, modified: values.contentModificationDate))
                } else {
                    childDirectories.append(url)
                }
            } else if values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                let modified = values.contentModificationDate ?? .now
                files.append(JunkFileRecord(url: url, size: size, modified: modified))
                if let kind = staleFileKind(url: url, modified: modified) {
                    candidates.append(JunkCandidate(url: url, kind: kind, reason: kind == .oldInstaller ? "Installer older than 90 days" : "Temporary file older than 30 days", size: size, group: nil, modified: modified))
                }
            }
        }
        return JunkDirectoryBatch(directory: directory, childDirectories: childDirectories, files: files, candidates: candidates, visited: visited)
    }

    // MARK: - Cross-Volume Exact Duplicates
    static func scanGlobalDuplicates() async throws -> [JunkCandidate] {
        let records = await JunkScanDatabase.shared.globalDuplicateRecords()
        var grouped: [String: [JunkFileRecord]] = [:]
        for record in records {
            try Task.checkCancellation()
            guard !shouldExclude(record.url.standardizedFileURL.path) else { continue }
            try await waitForIdle()
            guard isUnchanged(record.url, size: record.size, modified: record.modified) else { continue }
            let digest: String
            if let cached = await JunkScanDatabase.shared.digest(for: record.url, size: record.size, modified: record.modified) {
                digest = cached
            } else {
                guard let computed = try? await hash(record.url) else { continue }
                digest = computed
                await JunkScanDatabase.shared.saveDigest(digest, for: record.url, size: record.size, modified: record.modified)
            }
            guard isUnchanged(record.url, size: record.size, modified: record.modified) else { continue }
            grouped["\(record.size):\(digest)", default: []].append(record)
        }
        let candidates = grouped.flatMap { group, files -> [JunkCandidate] in
            guard files.count > 1 else { return [] }
            return files.map { file in
                JunkCandidate(url: file.url, kind: .duplicate, reason: "Exact content match in \(files.count) files across local volumes; keep at least one copy", size: file.size, group: group, modified: file.modified)
            }
        }
        await JunkScanDatabase.shared.saveGlobalCandidates(candidates)
        return candidates
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
        let excluded = ["/Library", "/.Trash", "/.git", "/.build", "/node_modules", "/.swiftpm", "/Applications", "/System", "/Develop", "/venvs", "/My Drive", "/Google Drive", "/Dropbox", "/OneDrive"]
        if path.contains("/Library/CloudStorage/") || path.hasSuffix("/Library/CloudStorage") { return true }
        if excluded.contains(where: { suffix in path == home + suffix || path.hasPrefix(home + suffix + "/") || path.contains(suffix + "/") }) { return true }
        return isDevelopmentTree(path)
    }

    // MARK: - Development Tree Guard
    private static func isDevelopmentTree(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        var current = URL(fileURLWithPath: path).standardizedFileURL
        var inspected: [NSString] = []
        while current.path != "/" && current.path != home {
            let key = current.path as NSString
            if let cached = developmentCache.object(forKey: key) {
                for item in inspected { developmentCache.setObject(cached, forKey: item) }
                return cached.boolValue
            }
            inspected.append(key)
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) ||
                FileManager.default.fileExists(atPath: current.appendingPathComponent("pyvenv.cfg").path) {
                for item in inspected { developmentCache.setObject(NSNumber(value: true), forKey: item) }
                return true
            }
            current.deleteLastPathComponent()
        }
        for item in inspected { developmentCache.setObject(NSNumber(value: false), forKey: item) }
        return false
    }

    private static func isEmptyDirectory(_ url: URL) -> Bool {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return items.isEmpty
    }

    // MARK: - Old Empty Directory
    static func isEligibleEmptyFolder(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeDirectory,
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) > 90 * 86400 else { return false }
        return isEmptyDirectory(url)
    }

    private static func staleFileKind(url: URL, modified: Date) -> JunkCandidate.Kind? {
        let age = Date().timeIntervalSince(modified)
        let ext = url.pathExtension.lowercased()
        if age > 90 * 86400 && ["dmg", "pkg", "xip"].contains(ext) { return .oldInstaller }
        if age > 30 * 86400 && ["tmp", "temp", "part"].contains(ext) { return .temporary }
        return nil
    }

    // MARK: - Leaf Folder Signature
    private static func leafFolderSignature(_ directory: URL, requireIdle: Bool = true) async -> (String, Int64)? {
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
            if requireIdle, let cached = await JunkScanDatabase.shared.digest(for: child, size: size, modified: modified) {
                digest = cached
            } else {
                guard let computed = try? await hash(child, requireIdle: requireIdle) else { return nil }
                digest = computed
                if requireIdle { await JunkScanDatabase.shared.saveDigest(digest, for: child, size: size, modified: modified) }
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

    // MARK: - Recheck Duplicate Before Trash
    static func stillMatchesDuplicate(_ candidate: JunkCandidate) async -> Bool {
        guard let group = candidate.group else { return true }
        let url = candidate.url
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true else { return false }
        if candidate.kind == .duplicateFolder {
            guard let signature = await leafFolderSignature(url, requireIdle: false) else { return false }
            return group == "folder:\(signature.0)" && candidate.size == signature.1
        }
        guard candidate.kind == .duplicate,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              Int64(values.fileSize ?? -1) == candidate.size,
              let digest = try? await hash(url, requireIdle: false) else { return false }
        return group == "\(candidate.size):\(digest)"
    }

    // MARK: - Recheck Candidate Before Trash
    static func stillMatchesCandidate(_ candidate: JunkCandidate) async -> Bool {
        if candidate.group != nil { return await stillMatchesDuplicate(candidate) }
        let url = candidate.url
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .contentModificationDateKey]),
              values.isSymbolicLink != true else { return false }
        switch candidate.kind {
        case .emptyFolder:
            return isEligibleEmptyFolder(url)
        case .oldInstaller, .temporary:
            return values.isRegularFile == true && values.contentModificationDate.map { staleFileKind(url: url, modified: $0) == candidate.kind } == true
        case .appLeftover:
            return values.contentModificationDate.map { Date().timeIntervalSince($0) > 180 * 86400 } == true
        case .processArtifact:
            return values.isRegularFile == true && values.contentModificationDate.map { Date().timeIntervalSince($0) > 30 * 86400 } == true
                && processID(in: url).map { !isProcessRunning($0) } == true
        case .duplicate, .duplicateFolder:
            return false
        }
    }

    // MARK: - File Digest
    private static func hash(_ url: URL, requireIdle: Bool = true) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var chunks = 0
        while true {
            if requireIdle && chunks.isMultiple(of: 8) { try await waitForIdle() }
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
    case databaseFailure
    var errorDescription: String? {
        switch self {
        case .unsafeLocation: "Choose a local folder inside your home directory. System and cloud folders are excluded."
        case .unreadableLocation: "The selected folder cannot be read."
        case .databaseFailure: "The cleanup database could not save scan progress."
        }
    }
}

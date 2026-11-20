// RemoteFindFilesEngine.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Searches a connected remote directory without routing its URL through local find.

import FileModelKit
import FindFilesKit
import Foundation

// MARK: - Remote Search Entry
struct RemoteSearchEntry: Sendable {
    let item: RemoteFileItem
    let accessed: Date?
}

// MARK: - Remote Search Error
enum RemoteFindFilesError: LocalizedError {
    case unavailableAccessDates
    case invalidNamePattern
    case invalidContentPattern
    var errorDescription: String? {
        switch self {
        case .unavailableAccessDates: "This server does not provide access dates for the selected filter. Choose Modified instead."
        case .invalidNamePattern: "The file-name regular expression is invalid."
        case .invalidContentPattern: "The content regular expression is invalid."
        }
    }
}

// MARK: - Remote Search Path Scope
enum RemoteSearchPathScope {
    static func contains(_ path: String, root: String) -> Bool {
        let candidate = (path as NSString).standardizingPath
        let selected = (root as NSString).standardizingPath
        return candidate != selected && (selected == "/" || candidate.hasPrefix(selected + "/"))
    }
}

// MARK: - Remote Find Files Engine
actor RemoteFindFilesEngine {
    private(set) var stats = FindFilesStats()
    private static let documentExtensions: Set<String> = ["pdf", "docx", "xlsx", "pptx"]
    private static let bundleExtensions: Set<String> = [
        "app", "framework", "plugin", "kext", "bundle", "appex", "qlgenerator",
        "mdimporter", "xpc", "prefPane", "saver", "driver", "codex"
    ]
    func getStats() -> FindFilesStats { stats }

    // MARK: - Search
    func search(
        criteria: FindFilesCriteria,
        provider: any RemoteFileProvider,
        passwordCallback: ArchivePasswordCallback?,
        onResult: @Sendable (FindFilesResult) async -> Void
    ) async throws {
        stats = FindFilesStats()
        stats.startTime = Date()
        stats.isRunning = true
        defer { stats.isRunning = false }
        let root = criteria.searchDirectory
        let rootPath = root.path.isEmpty ? "/" : root.path
        let nameRegex = try namePattern(for: criteria)
        let contentPattern = criteria.isContentSearch
            ? FindFilesContentSearcher.buildPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            : nil
        if criteria.isContentSearch && contentPattern == nil { throw RemoteFindFilesError.invalidContentPattern }
        let installedIdentities = criteria.applicationLeftoversOnly
            ? await remoteInstalledApplicationIdentities(provider: provider, root: root) : []
        var pending = [(rootPath, 0)]
        var delivered = 0
        while let (directory, depth) = pending.popLast() {
            try Task.checkCancellation()
            stats.currentPath = remoteURL(path: directory, root: root).absoluteString
            let entries: [RemoteSearchEntry]
            do {
                entries = try await provider.searchEntries(directory)
            } catch {
                if error is CancellationError { throw error }
                if depth == 0 { throw error }
                log.warning("[FindFiles] remote directory skipped '\(directory)': \(error.localizedDescription)")
                continue
            }
            if (criteria.accessBeforeDate != nil || criteria.accessOlderThanDays != nil)
                && entries.contains(where: { $0.accessed == nil }) {
                throw RemoteFindFilesError.unavailableAccessDates
            }
            stats.directoriesScanned += 1
            for entry in entries {
                try Task.checkCancellation()
                let item = entry.item
                guard RemoteSearchPathScope.contains(item.path, root: rootPath) else { continue }
                if delivered >= criteria.resultLimit {
                    stats.resultLimitReached = true
                    return
                }
                if item.isDirectory && criteria.searchInSubdirectories && depth < criteria.maxDepth
                    && !shouldPrune(item, criteria: criteria) {
                    pending.append((item.path, depth + 1))
                }
                guard !shouldPrune(item, criteria: criteria) else { continue }
                stats.filesScanned += item.isDirectory ? 0 : 1
                let itemURL = remoteURL(path: item.path, root: root)
                stats.currentPath = itemURL.absoluteString
                if !item.isDirectory && !criteria.emptyFoldersOnly && criteria.searchInArchives
                    && ArchiveExtensions.isArchive(item.fileExtension.lowercased()) {
                    do {
                        delivered += try await searchArchive(item, url: itemURL, criteria: criteria, provider: provider,
                            passwordCallback: passwordCallback, onResult: onResult, remaining: criteria.resultLimit - delivered)
                    } catch {
                        if error is CancellationError { throw error }
                        log.warning("[FindFiles] remote archive skipped '\(item.path)': \(error.localizedDescription)")
                    }
                    continue
                }
                guard try matches(item, criteria: criteria, nameRegex: nameRegex,
                    installedIdentities: installedIdentities, accessed: entry.accessed) else { continue }
                if item.isDirectory {
                    if criteria.itemType == .filesOnly || criteria.isContentSearch { continue }
                    if criteria.emptyFoldersOnly {
                        let children = try await provider.listDirectory(item.path)
                        if !children.isEmpty { continue }
                    }
                    await onResult(FindFilesResult(fileURL: itemURL, knownSize: 0, knownDate: item.modified))
                    delivered += 1
                    stats.matchesFound += 1
                    continue
                }
                if criteria.itemType == .foldersOnly || criteria.emptyFoldersOnly { continue }
                if let contentPattern {
                    do {
                        delivered += try await searchContent(item, url: itemURL, pattern: contentPattern,
                            provider: provider, onResult: onResult, remaining: criteria.resultLimit - delivered)
                    } catch {
                        if error is CancellationError { throw error }
                        log.warning("[FindFiles] remote content skipped '\(item.path)': \(error.localizedDescription)")
                    }
                    continue
                }
                await onResult(FindFilesResult(fileURL: itemURL, knownSize: item.size, knownDate: item.modified))
                delivered += 1
                stats.matchesFound += 1
            }
        }
    }

    // MARK: - Item Filters
    private func matches(_ item: RemoteFileItem, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
                         installedIdentities: Set<String>, accessed: Date?) throws -> Bool {
        let candidate = criteria.useRegex ? item.path : item.name
        let matched = nameRegex?.firstMatch(in: candidate, range: NSRange(candidate.startIndex..., in: candidate)) != nil
        let nameMatches = nameRegex == nil ? true : matched
        guard criteria.invertFileNamePattern ? !nameMatches : nameMatches else { return false }
        if criteria.deletableOnly, let permissions = item.permissions, !permissions.contains("w") { return false }
        if let min = criteria.fileSizeMin, !item.isDirectory, item.size < min { return false }
        if let max = criteria.fileSizeMax, !item.isDirectory, item.size > max { return false }
        if let from = criteria.dateFrom, (item.modified ?? .distantPast) < from { return false }
        if let to = criteria.dateTo, (item.modified ?? .distantFuture) > to { return false }
        if let before = criteria.modificationBeforeDate, (item.modified ?? .distantFuture) >= before { return false }
        if let days = criteria.modificationOlderThanDays, days > 0,
           (item.modified ?? .distantFuture) >= Date().addingTimeInterval(TimeInterval(-days * 86_400)) { return false }
        let needsAccess = criteria.accessBeforeDate != nil || criteria.accessOlderThanDays != nil
        if needsAccess && accessed == nil { throw RemoteFindFilesError.unavailableAccessDates }
        if let before = criteria.accessBeforeDate, let accessed, accessed >= before { return false }
        if let days = criteria.accessOlderThanDays, days > 0, let accessed,
           accessed >= Date().addingTimeInterval(TimeInterval(-days * 86_400)) { return false }
        if criteria.applicationLeftoversOnly {
            let url = URL(fileURLWithPath: item.path)
            guard item.path.contains("/Library/"),
                  FindFilesLeftoverSafety.isCandidate(url, installedIdentities: installedIdentities) else { return false }
        }
        return true
    }

    private func remoteInstalledApplicationIdentities(provider: any RemoteFileProvider, root: URL) async -> Set<String> {
        let parts = root.path.split(separator: "/")
        let userApplications = parts.count >= 2 && parts[0] == "Users"
            ? "/Users/\(parts[1])/Applications" : ""
        var identities = Set<String>()
        for path in ["/Applications", "/System/Applications", userApplications] where !path.isEmpty {
            guard let apps = try? await provider.listDirectory(path) else { continue }
            for app in apps where app.name.lowercased().hasSuffix(".app") {
                identities.insert(String(app.name.dropLast(4)).lowercased())
            }
        }
        return identities
    }

    private func namePattern(for criteria: FindFilesCriteria) throws -> NSRegularExpression? {
        let pattern = FindFilesNameMatcher.normalizedPattern(criteria.fileNamePattern)
        if pattern == "*" { return nil }
        if criteria.useRegex {
            let options: NSRegularExpression.Options = criteria.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                throw RemoteFindFilesError.invalidNamePattern
            }
            return regex
        }
        return FindFilesNameMatcher.buildRegex(pattern: pattern, caseSensitive: criteria.caseSensitive)
    }

    private func shouldPrune(_ item: RemoteFileItem, criteria: FindFilesCriteria) -> Bool {
        guard item.isDirectory else { return false }
        if item.name == ".Trash" || Self.bundleExtensions.contains((item.name as NSString).pathExtension.lowercased()) { return true }
        guard criteria.excludeSystemLocations else { return false }
        if ["node_modules", ".git", ".svn", ".hg"].contains(item.name) { return true }
        if ["/System", "/private", "/usr", "/bin", "/sbin", "/dev", "/cores", "/Network"].contains(item.path) { return true }
        return ["/Library/Mobile Documents", "/Library/CloudStorage", "/Library/Containers", "/Library/Group Containers"]
            .contains { item.path.hasSuffix($0) }
    }

    // MARK: - Remote Content
    private func searchContent(_ item: RemoteFileItem, url: URL, pattern: NSRegularExpression,
                               provider: any RemoteFileProvider, onResult: @Sendable (FindFilesResult) async -> Void,
                               remaining: Int) async throws -> Int {
        guard FindFilesContentSearcher.isLikelyTextFile(url: url)
            || Self.documentExtensions.contains(item.fileExtension.lowercased()) else { return 0 }
        let localURL = try await provider.downloadFile(remotePath: item.path)
        defer { removeTemporaryDownload(localURL) }
        var count = 0
        for match in FindFilesContentSearcher.searchFileContent(fileURL: localURL, pattern: pattern) {
            try Task.checkCancellation()
            guard count < remaining else { stats.resultLimitReached = true; break }
            await onResult(FindFilesResult(fileURL: url, matchContext: match.matchContext,
                lineNumber: match.lineNumber, knownSize: item.size, knownDate: item.modified))
            count += 1
            stats.matchesFound += 1
        }
        return count
    }

    private func searchArchive(_ item: RemoteFileItem, url: URL, criteria: FindFilesCriteria,
                               provider: any RemoteFileProvider, passwordCallback: ArchivePasswordCallback?,
                               onResult: @Sendable (FindFilesResult) async -> Void, remaining: Int) async throws -> Int {
        let localURL = try await provider.downloadFile(remotePath: item.path)
        defer { removeTemporaryDownload(localURL) }
        var localCriteria = criteria
        localCriteria.searchDirectory = localURL
        localCriteria.isArchiveOnlySearch = true
        localCriteria.resultLimit = remaining
        let engine = FindFilesEngine()
        let stream = await engine.search(criteria: localCriteria, passwordCallback: passwordCallback)
        var count = 0
        for await match in stream {
            try Task.checkCancellation()
            guard count < remaining else { stats.resultLimitReached = true; break }
            let suffix = match.filePath.hasPrefix(localURL.path) ? String(match.filePath.dropFirst(localURL.path.count)) : "/\(match.fileName)"
            let remoteEntryURL = remoteURL(path: item.path + suffix, root: url)
            await onResult(FindFilesResult(fileURL: remoteEntryURL, matchContext: match.matchContext,
                lineNumber: match.lineNumber, isInsideArchive: true, archivePath: url.absoluteString,
                knownSize: match.fileSize, knownDate: match.modifiedDate,
                isPasswordProtected: match.isPasswordProtected))
            count += 1
            stats.matchesFound += 1
        }
        stats.archivesScanned += 1
        return count
    }

    private func remoteURL(path: String, root: URL) -> URL {
        var components = URLComponents(url: root, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }

    private func removeTemporaryDownload(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if UUID(uuidString: url.deletingLastPathComponent().lastPathComponent) != nil {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
}

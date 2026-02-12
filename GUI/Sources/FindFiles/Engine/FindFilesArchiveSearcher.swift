// FindFilesArchiveSearcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search inside archives — ZIP, 7z, TAR families, password-protected archives

import Foundation

// MARK: - Archive Search Delta
/// Returned from archive search to let the caller update its own stats
struct ArchiveSearchDelta: Sendable {
    var matchesFound: Int = 0
}

// MARK: - Archive Searcher
/// Stateless utility — searches inside archive files for matching entries (by name and content).
/// Returns match count delta so the caller (FindFilesEngine actor) updates its own stats.
enum FindFilesArchiveSearcher {

    // MARK: - Route to Correct Handler

    @concurrent static func searchInsideArchive(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        let ext = archiveURL.pathExtension.lowercased()

        switch ext {
        case "zip":
            return await searchInsideZip(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                         contentPattern: contentPattern, continuation: continuation,
                                         passwordCallback: passwordCallback)
        case "7z":
            return await searchInside7z(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                        contentPattern: contentPattern, continuation: continuation,
                                        passwordCallback: passwordCallback)
        case "tar", "tgz", "gz", "gzip", "bz2", "bzip2", "xz", "txz", "lzma", "tlz",
             "tbz", "tbz2", "z":
            return await searchInsideTar(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                         contentPattern: contentPattern, continuation: continuation)
        case "jar", "war", "ear", "aar", "apk":
            return await searchInsideZip(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                         contentPattern: contentPattern, continuation: continuation,
                                         passwordCallback: passwordCallback)
        default:
            log.debug("[ArchiveSearcher] Using 7z fallback for \(archiveURL.lastPathComponent)")
            return await searchInside7z(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                        contentPattern: contentPattern, continuation: continuation,
                                        passwordCallback: passwordCallback)
        }
    }

    // MARK: - ZIP Search

    @concurrent private static func searchInsideZip(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = ["-l", archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch {
            log.error("[ArchiveSearcher] Failed to list zip: \(archiveURL.path) — \(error)")
            return ArchiveSearchDelta()
        }

        if listProcess.terminationStatus != 0 {
            if let callback = passwordCallback {
                log.info("[ArchiveSearcher] ZIP may be password-protected: \(archiveURL.lastPathComponent)")
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    return await searchInsideZipWithPassword(archiveURL: archiveURL, password: pwd, criteria: criteria,
                                                            nameRegex: nameRegex, contentPattern: contentPattern,
                                                            continuation: continuation)
                case .skip:
                    log.info("[ArchiveSearcher] Skipped password-protected: \(archiveURL.lastPathComponent)")
                    return ArchiveSearchDelta()
                }
            }
            return ArchiveSearchDelta()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return await processZipListing(listing, archiveURL: archiveURL, criteria: criteria,
                                       nameRegex: nameRegex, contentPattern: contentPattern,
                                       continuation: continuation)
    }

    @concurrent private static func searchInsideZipWithPassword(
        archiveURL: URL, password: String, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = ["-l", "-P", password, archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch { return ArchiveSearchDelta() }

        guard listProcess.terminationStatus == 0 else { return ArchiveSearchDelta() }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return await processZipListing(listing, archiveURL: archiveURL, criteria: criteria,
                                       nameRegex: nameRegex, contentPattern: contentPattern,
                                       continuation: continuation)
    }

    @concurrent private static func processZipListing(
        _ listing: String, archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return delta }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let components = trimmed.split(separator: " ", maxSplits: 3)
            guard components.count >= 4 else { continue }
            let entryName = String(components[3])
            guard !entryName.hasSuffix("/") else { continue }

            let fileName = (entryName as NSString).lastPathComponent
            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                if let contentPattern, criteria.isContentSearch {
                    let contentDelta = await searchZipEntryContent(
                        archiveURL: archiveURL, entryName: entryName,
                        contentPattern: contentPattern, continuation: continuation)
                    delta.matchesFound += contentDelta.matchesFound
                } else {
                    let virtualURL = archiveURL.appendingPathComponent(entryName)
                    let result = FindFilesResult(fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                    continuation.yield(result)
                    delta.matchesFound += 1
                }
            }
        }
        return delta
    }

    @concurrent private static func searchZipEntryContent(
        archiveURL: URL, entryName: String, contentPattern: NSRegularExpression,
        continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()

        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        extractProcess.arguments = ["-p", archiveURL.path, entryName]
        let pipe = Pipe()
        extractProcess.standardOutput = pipe
        extractProcess.standardError = Pipe()

        do {
            try extractProcess.run()
            extractProcess.waitUntilExit()
        } catch { return delta }

        guard extractProcess.terminationStatus == 0 else { return delta }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let content = String(data: data, encoding: .utf8) else { return delta }

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            guard !Task.isCancelled else { return delta }
            let range = NSRange(line.startIndex..., in: line)
            if contentPattern.firstMatch(in: line, range: range) != nil {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL, matchContext: String(line.prefix(200)),
                    lineNumber: index + 1, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }
        return delta
    }

    // MARK: - 7z Search

    @concurrent private static func searchInside7z(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            log.warning("[ArchiveSearcher] 7z not found — skipping \(archiveURL.lastPathComponent)")
            return ArchiveSearchDelta()
        }

        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: szPath)
        listProcess.arguments = ["l", archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch { return ArchiveSearchDelta() }

        if listProcess.terminationStatus != 0 {
            if let callback = passwordCallback {
                log.info("[ArchiveSearcher] 7z may need password: \(archiveURL.lastPathComponent)")
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    return await searchInside7zWithPassword(archiveURL: archiveURL, password: pwd, szPath: szPath,
                                                           criteria: criteria, nameRegex: nameRegex,
                                                           contentPattern: contentPattern,
                                                           continuation: continuation)
                case .skip:
                    return ArchiveSearchDelta()
                }
            }
            return ArchiveSearchDelta()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return process7zListing(listing, archiveURL: archiveURL, criteria: criteria,
                                nameRegex: nameRegex, continuation: continuation)
    }

    @concurrent private static func searchInside7zWithPassword(
        archiveURL: URL, password: String, szPath: String, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: szPath)
        listProcess.arguments = ["l", "-p\(password)", archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch { return ArchiveSearchDelta() }

        guard listProcess.terminationStatus == 0 else { return ArchiveSearchDelta() }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return process7zListing(listing, archiveURL: archiveURL, criteria: criteria,
                                nameRegex: nameRegex, continuation: continuation)
    }

    private static func process7zListing(
        _ listing: String, archiveURL: URL, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation
    ) -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let lines = listing.components(separatedBy: .newlines)
        var inFileList = false

        for line in lines {
            guard !Task.isCancelled else { return delta }
            if line.hasPrefix("---") {
                inFileList.toggle()
                continue
            }
            guard inFileList else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            let attrs = String(components[2])
            guard !attrs.hasPrefix("D") else { continue }
            let entryName = components[5...].joined(separator: " ")
            let fileName = (entryName as NSString).lastPathComponent

            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }
        return delta
    }

    // MARK: - TAR Search

    @concurrent static func searchInsideTar(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let ext = archiveURL.pathExtension.lowercased()
        var args = ["-tf"]
        switch ext {
        case "gz", "gzip", "tgz": args.insert("-z", at: 0)
        case "bz2", "bzip2", "tbz", "tbz2": args.insert("-j", at: 0)
        case "xz", "txz": args.insert("-J", at: 0)
        case "z": args.insert("-Z", at: 0)
        default: break
        }
        args.append(archiveURL.path)

        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        listProcess.arguments = args
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch {
            log.error("[ArchiveSearcher] tar list failed: \(archiveURL.lastPathComponent) — \(error)")
            return delta
        }

        guard listProcess.terminationStatus == 0 else {
            log.warning("[ArchiveSearcher] tar exit code \(listProcess.terminationStatus) for \(archiveURL.lastPathComponent)")
            return delta
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return delta }

        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return delta }
            let entryName = line.trimmingCharacters(in: .whitespaces)
            guard !entryName.isEmpty, !entryName.hasSuffix("/") else { continue }
            let fileName = (entryName as NSString).lastPathComponent

            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }
        return delta
    }
}

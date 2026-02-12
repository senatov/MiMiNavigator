// FindFilesArchiveSearcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search inside archives — ZIP, 7z, TAR families, password-protected archives

import Foundation

// MARK: - Archive Searcher
/// Searches inside archive files for matching entries (by name and content)
actor FindFilesArchiveSearcher {

    // MARK: - Route to Correct Handler

    func searchInsideArchive(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        stats: inout FindFilesStats
    ) async {
        let ext = archiveURL.pathExtension.lowercased()

        switch ext {
        case "zip":
            await searchInsideZip(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                  contentPattern: contentPattern, continuation: continuation,
                                  passwordCallback: passwordCallback, stats: &stats)
        case "7z":
            await searchInside7z(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                 contentPattern: contentPattern, continuation: continuation,
                                 passwordCallback: passwordCallback, stats: &stats)
        case "tar", "tgz", "gz", "gzip", "bz2", "bzip2", "xz", "txz", "lzma", "tlz",
             "tbz", "tbz2", "z":
            await searchInsideTar(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                  contentPattern: contentPattern, continuation: continuation, stats: &stats)
        case "jar", "war", "ear", "aar", "apk":
            // Java/Android archives are ZIP-based
            await searchInsideZip(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                  contentPattern: contentPattern, continuation: continuation,
                                  passwordCallback: passwordCallback, stats: &stats)
        default:
            // All other formats — try 7z as universal fallback
            log.debug("[ArchiveSearcher] Using 7z fallback for \(archiveURL.lastPathComponent)")
            await searchInside7z(archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                                 contentPattern: contentPattern, continuation: continuation,
                                 passwordCallback: passwordCallback, stats: &stats)
        }
    }

    // MARK: - ZIP Search

    private func searchInsideZip(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?, stats: inout FindFilesStats
    ) async {
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
            return
        }

        if listProcess.terminationStatus != 0 {
            // Might be password-protected
            if let callback = passwordCallback {
                log.info("[ArchiveSearcher] ZIP may be password-protected: \(archiveURL.lastPathComponent)")
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    await searchInsideZipWithPassword(archiveURL: archiveURL, password: pwd, criteria: criteria,
                                                     nameRegex: nameRegex, contentPattern: contentPattern,
                                                     continuation: continuation, stats: &stats)
                case .skip:
                    log.info("[ArchiveSearcher] Skipped password-protected: \(archiveURL.lastPathComponent)")
                    return
                }
            }
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        await processZipListing(listing, archiveURL: archiveURL, criteria: criteria,
                                nameRegex: nameRegex, contentPattern: contentPattern,
                                continuation: continuation, stats: &stats)
    }

    private func searchInsideZipWithPassword(
        archiveURL: URL, password: String, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        stats: inout FindFilesStats
    ) async {
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = ["-l", "-P", password, archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch { return }

        guard listProcess.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        await processZipListing(listing, archiveURL: archiveURL, criteria: criteria,
                                nameRegex: nameRegex, contentPattern: contentPattern,
                                continuation: continuation, stats: &stats)
    }

    private func processZipListing(
        _ listing: String, archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        stats: inout FindFilesStats
    ) async {
        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return }
            // Parse unzip -l output: "  12345  01-01-2024 12:00   path/to/file.txt"
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let components = trimmed.split(separator: " ", maxSplits: 3)
            guard components.count >= 4 else { continue }
            let entryName = String(components[3])
            guard !entryName.hasSuffix("/") else { continue }

            let fileName = (entryName as NSString).lastPathComponent
            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                if let contentPattern, criteria.isContentSearch {
                    await searchZipEntryContent(archiveURL: archiveURL, entryName: entryName,
                                                contentPattern: contentPattern, continuation: continuation, stats: &stats)
                } else {
                    let virtualURL = archiveURL.appendingPathComponent(entryName)
                    let result = FindFilesResult(fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            }
        }
    }

    private func searchZipEntryContent(
        archiveURL: URL, entryName: String, contentPattern: NSRegularExpression,
        continuation: AsyncStream<FindFilesResult>.Continuation, stats: inout FindFilesStats
    ) async {
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        extractProcess.arguments = ["-p", archiveURL.path, entryName]
        let pipe = Pipe()
        extractProcess.standardOutput = pipe
        extractProcess.standardError = Pipe()

        do {
            try extractProcess.run()
            extractProcess.waitUntilExit()
        } catch { return }

        guard extractProcess.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let content = String(data: data, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            guard !Task.isCancelled else { return }
            let range = NSRange(line.startIndex..., in: line)
            if contentPattern.firstMatch(in: line, range: range) != nil {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL, matchContext: String(line.prefix(200)),
                    lineNumber: index + 1, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }

    // MARK: - 7z Search

    private func searchInside7z(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?, stats: inout FindFilesStats
    ) async {
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            log.warning("[ArchiveSearcher] 7z not found — skipping \(archiveURL.lastPathComponent)")
            return
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
        } catch { return }

        if listProcess.terminationStatus != 0 {
            if let callback = passwordCallback {
                log.info("[ArchiveSearcher] 7z may need password: \(archiveURL.lastPathComponent)")
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    await searchInside7zWithPassword(archiveURL: archiveURL, password: pwd, szPath: szPath,
                                                    criteria: criteria, nameRegex: nameRegex,
                                                    contentPattern: contentPattern,
                                                    continuation: continuation, stats: &stats)
                case .skip:
                    return
                }
            }
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        await process7zListing(listing, archiveURL: archiveURL, criteria: criteria,
                               nameRegex: nameRegex, continuation: continuation, stats: &stats)
    }

    private func searchInside7zWithPassword(
        archiveURL: URL, password: String, szPath: String, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation, stats: inout FindFilesStats
    ) async {
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: szPath)
        listProcess.arguments = ["l", "-p\(password)", archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch { return }

        guard listProcess.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        await process7zListing(listing, archiveURL: archiveURL, criteria: criteria,
                               nameRegex: nameRegex, continuation: continuation, stats: &stats)
    }

    private func process7zListing(
        _ listing: String, archiveURL: URL, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        stats: inout FindFilesStats
    ) async {
        let lines = listing.components(separatedBy: .newlines)
        var inFileList = false

        for line in lines {
            guard !Task.isCancelled else { return }
            if line.hasPrefix("---") {
                inFileList.toggle()
                continue
            }
            guard inFileList else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // 7z list format: "2024-01-01 12:00:00 D....    0    0  dirname"
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
                stats.matchesFound += 1
            }
        }
    }

    // MARK: - TAR Search

    func searchInsideTar(
        archiveURL: URL, criteria: FindFilesCriteria, nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        stats: inout FindFilesStats
    ) async {
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
            return
        }

        guard listProcess.terminationStatus == 0 else {
            log.warning("[ArchiveSearcher] tar exit code \(listProcess.terminationStatus) for \(archiveURL.lastPathComponent)")
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return }
            let entryName = line.trimmingCharacters(in: .whitespaces)
            guard !entryName.isEmpty, !entryName.hasSuffix("/") else { continue }
            let fileName = (entryName as NSString).lastPathComponent

            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }
}

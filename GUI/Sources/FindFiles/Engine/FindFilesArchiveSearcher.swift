// FindFilesArchiveSearcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Rewritten: 14.02.2026 — native ZIP reader, no Process() for ZIP-based formats
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search inside archives — native ZIP reader for ZIP/JAR/WAR/APK,
//              CLI fallback for TAR/7z. Supports name matching + content search.

import Foundation

// MARK: - Archive Search Delta

/// Returned from archive search to let the caller update its own stats
struct ArchiveSearchDelta: Sendable {
    var matchesFound: Int = 0
}

// MARK: - Archive Searcher

/// Searches inside archive files for matching entries (by name and optionally content).
/// ZIP-based formats use NativeZipReader (no Process spawning).
/// TAR and 7z formats use optimized CLI calls as fallback.
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
        let startTime = ContinuousClock.now

        let delta: ArchiveSearchDelta

        // ZIP-based formats — use native reader (fast, no Process)
        if NativeZipReader.isZipBased(ext) {
            delta = await searchInsideZipNative(
                archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                contentPattern: contentPattern, continuation: continuation,
                passwordCallback: passwordCallback
            )
        } else {
            // TAR family — CLI fallback
            switch ext {
            case "tar", "tgz", "gz", "gzip", "bz2", "bzip2", "xz", "txz", "lzma", "tlz",
                "tbz", "tbz2", "z":
                delta = await searchInsideTar(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation
                )

            case "7z":
                delta = await searchInside7z(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation,
                    passwordCallback: passwordCallback
                )

            default:
                // Try native ZIP first (many formats are secretly ZIP), fallback to 7z
                let zipDelta = await searchInsideZipNative(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation,
                    passwordCallback: nil
                )
                if zipDelta.matchesFound > 0 {
                    delta = zipDelta
                } else {
                    log.debug("[ArchiveSearcher] ZIP failed for \(archiveURL.lastPathComponent), trying 7z fallback")
                    delta = await searchInside7z(
                        archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                        contentPattern: contentPattern, continuation: continuation,
                        passwordCallback: passwordCallback
                    )
                }
            }
        }

        let elapsed = ContinuousClock.now - startTime
        log.info("[ArchiveSearcher] \(archiveURL.lastPathComponent): \(delta.matchesFound) matches in \(elapsed)")
        return delta
    }

    // MARK: - Native ZIP Search (no Process)

    @concurrent private static func searchInsideZipNative(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let archivePath = archiveURL.path

        // Step 1: Read central directory — this is the fast part (~0.1s for 50K entries)
        let entries: [ZipDirectoryEntry]
        let listStart = ContinuousClock.now
        do {
            entries = try NativeZipReader.listEntries(at: archivePath)
        } catch let error as ZipReadError {
            switch error {
            case .notAZipFile:
                log.debug("[ArchiveSearcher] Not a ZIP: \(archiveURL.lastPathComponent)")
                return delta
            case .passwordProtected:
                if let callback = passwordCallback {
                    log.info("[ArchiveSearcher] Password-protected ZIP: \(archiveURL.lastPathComponent)")
                    let response = await callback(archiveURL.lastPathComponent)
                    switch response {
                    case .password:
                        // Native reader can't handle encrypted ZIPs — fallback to CLI
                        return await searchInsideZipCLI(
                            archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                            contentPattern: contentPattern, continuation: continuation,
                            passwordCallback: passwordCallback
                        )
                    case .skip:
                        return delta
                    }
                }
                return delta
            default:
                log.error("[ArchiveSearcher] ZIP read error: \(archiveURL.lastPathComponent) — \(error)")
                return delta
            }
        } catch {
            log.error("[ArchiveSearcher] Unexpected error: \(archiveURL.lastPathComponent) — \(error)")
            return delta
        }

        log.debug("[ArchiveSearcher] ZIP listing: \(entries.count) entries in \(archiveURL.lastPathComponent) (\(ContinuousClock.now - listStart))")

        // Step 2: Filter by name pattern
        for entry in entries {
            guard !Task.isCancelled else { return delta }

            let baseName = entry.baseName
            guard FindFilesNameMatcher.matches(fileName: baseName, regex: nameRegex, criteria: criteria) else {
                continue
            }

            // Step 3: Content search if needed
            if let contentPattern, criteria.isContentSearch {
                // Only search text-like files
                guard FindFilesContentSearcher.isLikelyTextFile(
                    url: URL(fileURLWithPath: entry.fileName)
                ) else { continue }

                // Extract and search content — native, no Process
                do {
                    guard let text = try NativeZipReader.extractEntryText(at: archivePath, entry: entry) else {
                        continue
                    }
                    let lines = text.components(separatedBy: .newlines)
                    for (index, line) in lines.enumerated() {
                        guard !Task.isCancelled else { return delta }
                        let range = NSRange(line.startIndex..., in: line)
                        if contentPattern.firstMatch(in: line, range: range) != nil {
                            let virtualURL = archiveURL.appendingPathComponent(entry.fileName)
                            let result = FindFilesResult(
                                fileURL: virtualURL,
                                matchContext: String(line.prefix(200)),
                                lineNumber: index + 1,
                                isInsideArchive: true,
                                archivePath: archiveURL.path
                            )
                            continuation.yield(result)
                            delta.matchesFound += 1
                        }
                    }
                } catch ZipReadError.passwordProtected {
                    // Entry is encrypted — ask for password if callback available
                    if let callback = passwordCallback {
                        let response = await callback(archiveURL.lastPathComponent)
                        if case .skip = response { continue }
                        // For encrypted entries, fallback to CLI
                        return await searchInsideZipCLI(
                            archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                            contentPattern: contentPattern, continuation: continuation,
                            passwordCallback: passwordCallback
                        )
                    }
                } catch {
                    log.debug("[ArchiveSearcher] Cannot extract \(entry.fileName): \(error.localizedDescription)")
                    continue
                }
            } else {
                // Name-only match — yield immediately with real size from ZIP central directory
                let virtualURL = archiveURL.appendingPathComponent(entry.fileName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path,
                    knownSize: Int64(entry.uncompressedSize)
                )
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }

        return delta
    }

    // MARK: - ZIP CLI Fallback (for password-protected archives)

    @concurrent private static func searchInsideZipCLI(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        var password: String? = nil

        if let callback = passwordCallback {
            let response = await callback(archiveURL.lastPathComponent)
            switch response {
            case .password(let pwd): password = pwd
            case .skip: return ArchiveSearchDelta()
            }
        }

        var args = ["-l"]
        if let pwd = password { args.append(contentsOf: ["-P", pwd]) }
        args.append(archiveURL.path)

        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = args
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()

        do {
            try listProcess.run()
            listProcess.waitUntilExit()
        } catch {
            log.error("[ArchiveSearcher] CLI unzip failed: \(error)")
            return ArchiveSearchDelta()
        }

        guard listProcess.terminationStatus == 0 else { return ArchiveSearchDelta() }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return await processZipCLIListing(
            listing, archiveURL: archiveURL, password: password,
            criteria: criteria, nameRegex: nameRegex,
            contentPattern: contentPattern, continuation: continuation
        )
    }

    @concurrent private static func processZipCLIListing(
        _ listing: String,
        archiveURL: URL,
        password: String?,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
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
                    let contentDelta = await searchZipEntryContentCLI(
                        archiveURL: archiveURL, entryName: entryName, password: password,
                        contentPattern: contentPattern, continuation: continuation
                    )
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

    @concurrent private static func searchZipEntryContentCLI(
        archiveURL: URL,
        entryName: String,
        password: String?,
        contentPattern: NSRegularExpression,
        continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()

        var args = ["-p"]
        if let pwd = password { args.append(contentsOf: ["-P", pwd]) }
        args.append(contentsOf: [archiveURL.path, entryName])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch { return delta }

        guard process.terminationStatus == 0 else { return delta }

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
                    lineNumber: index + 1, isInsideArchive: true, archivePath: archiveURL.path
                )
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }
        return delta
    }

    // MARK: - 7z Search (CLI)

    @concurrent private static func searchInside7z(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
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
                    return await searchInside7zWithPassword(
                        archiveURL: archiveURL, password: pwd, szPath: szPath,
                        criteria: criteria, nameRegex: nameRegex,
                        contentPattern: contentPattern, continuation: continuation
                    )
                case .skip:
                    return ArchiveSearchDelta()
                }
            }
            return ArchiveSearchDelta()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return process7zListing(
            listing, archiveURL: archiveURL, criteria: criteria,
            nameRegex: nameRegex, continuation: continuation
        )
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

        return process7zListing(
            listing, archiveURL: archiveURL, criteria: criteria,
            nameRegex: nameRegex, continuation: continuation
        )
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

    // MARK: - TAR Search (CLI)

    @concurrent static func searchInsideTar(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
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
            log.warning("[ArchiveSearcher] tar exit \(listProcess.terminationStatus): \(archiveURL.lastPathComponent)")
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

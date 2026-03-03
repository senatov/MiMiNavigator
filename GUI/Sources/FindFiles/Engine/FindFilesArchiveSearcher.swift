// FindFilesArchiveSearcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Rewritten: 14.02.2026 — native ZIP reader, no Process() for ZIP-based formats
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search inside archives — native ZIP reader for ZIP/JAR/WAR/APK,
//              CLI fallback for TAR/7z. Supports name matching + content search.

import FileModelKit
import Foundation

// MARK: - Archive Search Delta

/// Returned from archive search to let the caller update its own stats
struct ArchiveSearchDelta: Sendable {
    var matchesFound: Int = 0
}

/// Callback for progress updates during archive search
typealias ArchiveProgressCallback = @concurrent @Sendable (String) async -> Void

// MARK: - Archive Searcher

/// Searches inside archive files for matching entries (by name and optionally content).
/// ZIP-based formats use NativeZipReader (no Process spawning).
/// TAR and 7z formats use optimized CLI calls as fallback.
enum FindFilesArchiveSearcher {

    /// Maximum recursion depth for nested archives (archive inside archive)
    static let maxRecursionDepth = 5

    /// Temporary directories created during recursive archive extraction.
    /// Must be cleaned up after search completes.
    private static let tempDirsLock = NSLock()
    private nonisolated(unsafe) static var tempDirs: [URL] = []

    // MARK: - Temp Directory Management

    static func registerTempDir(_ url: URL) {
        tempDirsLock.lock()
        tempDirs.append(url)
        tempDirsLock.unlock()
    }

    static func cleanupAllTempDirs() {
        tempDirsLock.lock()
        let dirs = tempDirs
        tempDirs.removeAll()
        tempDirsLock.unlock()
        let fm = FileManager.default
        for dir in dirs {
            try? fm.removeItem(at: dir)
        }
        if !dirs.isEmpty {
            log.info("[ArchiveSearcher] Cleaned up \(dirs.count) temp directories")
        }
    }

    // MARK: - Route to Correct Handler

    @concurrent static func searchInsideArchive(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        progressCallback: ArchiveProgressCallback? = nil,
        recursionDepth: Int = 0
    ) async -> ArchiveSearchDelta {
        guard recursionDepth < maxRecursionDepth else {
            log.warning("[ArchiveSearcher] Max recursion depth (\(maxRecursionDepth)) reached for \(archiveURL.lastPathComponent)")
            return ArchiveSearchDelta()
        }
        let ext = archiveURL.pathExtension.lowercased()
        let startTime = ContinuousClock.now

        let delta: ArchiveSearchDelta

        // ZIP-based formats — use native reader (fast, no Process)
        if NativeZipReader.isZipBased(ext) {
            delta = await searchInsideZipNative(
                archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                contentPattern: contentPattern, continuation: continuation,
                passwordCallback: passwordCallback, progressCallback: progressCallback,
                recursionDepth: recursionDepth
            )
        } else {
            // TAR family — CLI fallback
            switch ext {
            case "tar", "tgz", "gz", "gzip", "bz2", "bzip2", "xz", "txz", "lzma", "tlz",
                "tbz", "tbz2", "z":
                delta = await searchInsideTar(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation,
                    recursionDepth: recursionDepth
                )

            case "7z":
                delta = await searchInside7z(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation,
                    passwordCallback: passwordCallback, recursionDepth: recursionDepth
                )

            default:
                // Try native ZIP first (many formats are secretly ZIP), fallback to 7z
                let zipDelta = await searchInsideZipNative(
                    archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                    contentPattern: contentPattern, continuation: continuation,
                    passwordCallback: nil, recursionDepth: recursionDepth
                )
                if zipDelta.matchesFound > 0 {
                    delta = zipDelta
                } else {
                    log.debug("[ArchiveSearcher] ZIP failed for \(archiveURL.lastPathComponent), trying 7z fallback")
                    delta = await searchInside7z(
                        archiveURL: archiveURL, criteria: criteria, nameRegex: nameRegex,
                        contentPattern: contentPattern, continuation: continuation,
                        passwordCallback: passwordCallback, recursionDepth: recursionDepth
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
        passwordCallback: ArchivePasswordCallback?,
        progressCallback: ArchiveProgressCallback? = nil,
        recursionDepth: Int = 0
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
                // Add password-protected archive to results with lock icon, then continue
                log.info("[ArchiveSearcher] Password-protected ZIP: \(archiveURL.lastPathComponent)")
                let result = FindFilesResult(
                    fileURL: archiveURL,
                    matchContext: "🔒 Password protected",
                    isPasswordProtected: true
                )
                continuation.yield(result)
                delta.matchesFound += 1
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

            // Report progress: archive name + current entry
            if let progressCallback {
                await progressCallback("📦 \(archiveURL.lastPathComponent) → \(entry.fileName)")
            }

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
                                archivePath: archiveURL.path,
                                knownSize: Int64(entry.uncompressedSize),
                                knownDate: entry.modificationDate
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
                // Name-only match — yield immediately with real size and date from ZIP central directory
                let virtualURL = archiveURL.appendingPathComponent(entry.fileName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path,
                    knownSize: Int64(entry.uncompressedSize),
                    knownDate: entry.modificationDate
                )
                continuation.yield(result)
                delta.matchesFound += 1
            }
            // Recursive: if this entry is itself an archive, extract and search inside
            let entryExt = (entry.fileName as NSString).pathExtension.lowercased()
            if !entry.isDirectory && ArchiveExtensions.isArchive(entryExt) && recursionDepth < maxRecursionDepth {
                do {
                    let entryData = try NativeZipReader.extractEntryData(at: archivePath, entry: entry)
                    let tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("MiMiNav_nested_\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    registerTempDir(tempDir)
                    let nestedArchiveURL = tempDir.appendingPathComponent(entry.baseName)
                    try entryData.write(to: nestedArchiveURL)
                    let nestedDelta = await searchInsideArchive(
                        archiveURL: nestedArchiveURL, criteria: criteria,
                        nameRegex: nameRegex, contentPattern: contentPattern,
                        continuation: continuation, passwordCallback: passwordCallback,
                        recursionDepth: recursionDepth + 1
                    )
                    delta.matchesFound += nestedDelta.matchesFound
                } catch {
                    log.debug("[ArchiveSearcher] Cannot recurse into \(entry.baseName): \(error.localizedDescription)")
                }
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

    /// Timeout for 7z listing operation (seconds)
    private static let sevenZipTimeout: TimeInterval = 2.0

    @concurrent private static func searchInside7z(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        recursionDepth: Int = 0
    ) async -> ArchiveSearchDelta {
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            log.warning("[ArchiveSearcher] 7z not found — skipping \(archiveURL.lastPathComponent)")
            return ArchiveSearchDelta()
        }

        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: szPath)
        // -p flag with empty password prevents 7z from waiting for stdin
        listProcess.arguments = ["l", "-p", archiveURL.path]
        let pipe = Pipe()
        listProcess.standardOutput = pipe
        listProcess.standardError = Pipe()
        // Close stdin to prevent 7z from waiting for password input
        listProcess.standardInput = FileHandle.nullDevice

        do {
            try listProcess.run()
        } catch {
            log.error("[ArchiveSearcher] 7z launch failed: \(archiveURL.lastPathComponent) — \(error)")
            return ArchiveSearchDelta()
        }

        // Wait with timeout to prevent hanging on password-protected archives
        let completed = await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let deadline = DispatchTime.now() + sevenZipTimeout
                while listProcess.isRunning {
                    if DispatchTime.now() >= deadline {
                        // Timeout — kill the process
                        kill(listProcess.processIdentifier, SIGKILL)
                        cont.resume(returning: false)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                cont.resume(returning: true)
            }
        }

        if !completed || listProcess.terminationStatus != 0 {
            // 7z failed or timed out — likely password-protected
            log.info("[ArchiveSearcher] Password-protected 7z (timeout or error): \(archiveURL.lastPathComponent)")
            var delta = ArchiveSearchDelta()
            let result = FindFilesResult(
                fileURL: archiveURL,
                matchContext: "🔒 Password protected",
                isPasswordProtected: true
            )
            continuation.yield(result)
            delta.matchesFound += 1
            return delta
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return ArchiveSearchDelta() }

        return await process7zListing(
            listing, archiveURL: archiveURL, criteria: criteria,
            nameRegex: nameRegex, continuation: continuation,
            contentPattern: contentPattern, passwordCallback: passwordCallback,
            recursionDepth: recursionDepth
        )
    }

    @concurrent private static func searchInside7zWithPassword(
        archiveURL: URL, password: String, szPath: String, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback? = nil,
        recursionDepth: Int = 0
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

        return await process7zListing(
            listing, archiveURL: archiveURL, criteria: criteria,
            nameRegex: nameRegex, continuation: continuation,
            contentPattern: contentPattern, passwordCallback: passwordCallback,
            recursionDepth: recursionDepth
        )
    }

    private static func process7zListing(
        _ listing: String, archiveURL: URL, criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?, continuation: AsyncStream<FindFilesResult>.Continuation,
        contentPattern: NSRegularExpression?, passwordCallback: ArchivePasswordCallback?,
        recursionDepth: Int
    ) async -> ArchiveSearchDelta {
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

            // Parse 7z listing line:
            // Format: 2025-02-15 10:30:00 ....A  1234  512  path/to/file.txt
            //         date(0)   time(1)  attr(2) size(3) compressed(4) name(5+)
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }

            let attrs = String(components[2])
            // Skip directories (attrs starts with D)
            guard !attrs.hasPrefix("D") else { continue }

            // Parse date and time
            let dateStr = String(components[0])  // 2025-02-15
            let timeStr = String(components[1])  // 10:30:00
            let entryDate = parse7zDateTime("\(dateStr) \(timeStr)")

            // Parse size
            let entrySize = Int64(components[3]) ?? 0

            // Entry name is everything from component 5 onwards
            let entryName = components[5...].joined(separator: " ")
            let fileName = (entryName as NSString).lastPathComponent

            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path,
                    knownSize: entrySize,
                    knownDate: entryDate
                )
                continuation.yield(result)
                delta.matchesFound += 1
            }
            // Recursive: nested archive inside 7z
            let entryExt = (fileName as NSString).pathExtension.lowercased()
            if ArchiveExtensions.isArchive(entryExt) && recursionDepth < maxRecursionDepth {
                let nestedDelta = await extractAndRecurse(
                    archiveURL: archiveURL, entryName: entryName, criteria: criteria,
                    nameRegex: nameRegex, contentPattern: contentPattern,
                    continuation: continuation, passwordCallback: passwordCallback,
                    recursionDepth: recursionDepth
                )
                delta.matchesFound += nestedDelta.matchesFound
            }
        }
        return delta
    }

    /// Parse 7z date-time format: "2025-02-15 10:30:00"
    private static func parse7zDateTime(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    // MARK: - Extract nested archive and recurse
    /// Extracts a single entry from an archive to a temp dir and recursively searches inside it.
    @concurrent private static func extractAndRecurse(
        archiveURL: URL,
        entryName: String,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        recursionDepth: Int
    ) async -> ArchiveSearchDelta {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiNav_nested_\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            registerTempDir(tempDir)
            // Try extracting with 7z first (handles most formats)
            let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
            if let szPath = szPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: szPath)
                process.arguments = ["e", "-o\(tempDir.path)", "-y", archiveURL.path, entryName]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return ArchiveSearchDelta() }
            } else {
                // Fallback: try unzip
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-o", archiveURL.path, entryName, "-d", tempDir.path]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return ArchiveSearchDelta() }
            }
            let fileName = (entryName as NSString).lastPathComponent
            let extractedURL = tempDir.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: extractedURL.path) else { return ArchiveSearchDelta() }
            return await searchInsideArchive(
                archiveURL: extractedURL, criteria: criteria,
                nameRegex: nameRegex, contentPattern: contentPattern,
                continuation: continuation, passwordCallback: passwordCallback,
                recursionDepth: recursionDepth + 1
            )
        } catch {
            log.debug("[ArchiveSearcher] extractAndRecurse failed for \(entryName): \(error.localizedDescription)")
            return ArchiveSearchDelta()
        }
    }

    // MARK: - TAR Search (CLI)

    @concurrent static func searchInsideTar(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        recursionDepth: Int = 0
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let ext = archiveURL.pathExtension.lowercased()
        // Use -tvf for verbose output with size and date
        var args = ["-tvf"]
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
            // Parse verbose tar output: -rw-r--r--  0 user staff  1234 Feb 15 10:30 2025 path/to/file.txt
            // or: -rw-r--r--  user/staff  1234 2025-02-15 10:30 path/to/file.txt (GNU tar)
            let parsed = parseTarVerboseLine(line)
            guard let entry = parsed else { continue }
            guard !entry.isDirectory else { continue }

            let fileName = (entry.name as NSString).lastPathComponent

            if FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entry.name)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path,
                    knownSize: entry.size,
                    knownDate: entry.modificationDate
                )
                continuation.yield(result)
                delta.matchesFound += 1
            }
        }
        return delta
    }

    // MARK: - Parse TAR Verbose Line

    /// Parsed entry from tar -tv output
    private struct TarEntry {
        let name: String
        let size: Int64
        let modificationDate: Date?
        let isDirectory: Bool
    }

    /// Parse a single line from `tar -tvf` output.
    /// BSD tar format: -rw-r--r--  0 user staff    1234 Feb 15 10:30 2025 path/to/file
    /// GNU tar format: -rw-r--r-- user/staff    1234 2025-02-15 10:30 path/to/file
    private static func parseTarVerboseLine(_ line: String) -> TarEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // First character: d=directory, -=file, l=symlink, etc.
        let firstChar = trimmed.first ?? "-"
        let isDirectory = firstChar == "d"

        // Try BSD tar format first (macOS default)
        // Example: -rw-r--r--  0 senat staff     1234 Feb 15 10:30 2025 path/to/file.txt
        //          drwxr-xr-x  0 senat staff        0 Feb 15 10:30 2025 folder/
        if let entry = parseBSDTarLine(trimmed, isDirectory: isDirectory) {
            return entry
        }

        // Try GNU tar format
        // Example: -rw-r--r-- senat/staff     1234 2025-02-15 10:30 path/to/file.txt
        if let entry = parseGNUTarLine(trimmed, isDirectory: isDirectory) {
            return entry
        }

        return nil
    }

    /// Parse BSD tar -tv line (macOS)
    /// Format: -rw-r--r--  0 user staff    1234 Feb 15 10:30 2025 path/to/file
    private static func parseBSDTarLine(_ line: String, isDirectory: Bool) -> TarEntry? {
        // BSD tar uses: perms link user group size month day time year name
        // We need: size, month day time year, and everything after year as name

        // Split by whitespace, keeping track of positions
        let components = line.split(separator: " ", omittingEmptySubsequences: true)

        // Need at least: perms(0) link(1) user(2) group(3) size(4) month(5) day(6) time(7) year(8) name(9+)
        guard components.count >= 9 else { return nil }

        // Check if this looks like BSD format: component[5] should be month name
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let possibleMonth = String(components[5])
        guard monthNames.contains(possibleMonth) else { return nil }

        // Parse size (component 4)
        guard let size = Int64(components[4]) else { return nil }

        // Parse date: month(5) day(6) time(7) year(8)
        let month = possibleMonth
        let day = String(components[6])
        let time = String(components[7])
        let year = String(components[8])
        let dateString = "\(month) \(day) \(time) \(year)"
        let date = parseTarDate(dateString)

        // Name is everything after year — find position in original line
        // Join remaining components (handles spaces in filenames)
        let name: String
        if components.count > 9 {
            name = components[9...].joined(separator: " ")
        } else {
            // Only 9 components — name is last one
            return nil
        }

        guard !name.isEmpty else { return nil }

        return TarEntry(name: name, size: size, modificationDate: date, isDirectory: isDirectory)
    }

    /// Parse GNU tar -tv line
    /// Format: -rw-r--r-- user/group    1234 2025-02-15 10:30 path/to/file
    private static func parseGNUTarLine(_ line: String, isDirectory: Bool) -> TarEntry? {
        let components = line.split(separator: " ", omittingEmptySubsequences: true)

        // Need at least: perms(0) user/group(1) size(2) date(3) time(4) name(5+)
        guard components.count >= 5 else { return nil }

        // Check if component[1] contains "/" (user/group format)
        let userGroup = String(components[1])
        guard userGroup.contains("/") else { return nil }

        // Parse size (component 2)
        guard let size = Int64(components[2]) else { return nil }

        // Parse date: YYYY-MM-DD HH:MM
        let dateStr = String(components[3])
        let timeStr = String(components[4])
        let date = parseISODate("\(dateStr) \(timeStr)")

        // Name is everything from component 5 onwards
        guard components.count > 5 else { return nil }
        let name = components[5...].joined(separator: " ")
        guard !name.isEmpty else { return nil }

        return TarEntry(name: name, size: size, modificationDate: date, isDirectory: isDirectory)
    }

    /// Parse BSD tar date format: "Feb 15 10:30 2025"
    private static func parseTarDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d HH:mm yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try with 2-digit day
        formatter.dateFormat = "MMM dd HH:mm yyyy"
        return formatter.date(from: dateString)
    }

    /// Parse ISO date format: "2025-02-15 10:30"
    private static func parseISODate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: dateString)
    }
}

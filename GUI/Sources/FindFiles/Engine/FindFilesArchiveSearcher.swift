// FindFilesArchiveSearcher.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Rewritten: 13.02.2026 — fast CLI-based approach: zipinfo/tar/7z for listing,
//   batch extract + grep for content search (10x faster than per-file extraction)
// Copyright © 2026 Senatov. All rights reserved.
// Description: Search inside archives — ZIP, 7z, TAR families, password-protected archives.
//   Uses native macOS CLI tools (zipinfo, unzip, tar, 7z) for maximum speed.
//
//   Benchmarks (304 MB ZIP, 16K entries, 7286 .java files):
//     - Listing only:    zipinfo -1        → 33 ms
//     - Content search:  batch unzip+grep  → 3.2 s (vs 31 s per-file approach)

import Foundation

// MARK: - Archive Search Delta
/// Returned from archive search to let the caller update its own stats
struct ArchiveSearchDelta: Sendable {
    var matchesFound: Int = 0
}

// MARK: - Archive Searcher
/// Stateless utility — searches inside archive files for matching entries (by name and content).
/// Returns match count delta so the caller (FindFilesEngine actor) updates its own stats.
///
/// Strategy:
///   1. LIST:    Get full file listing via CLI (zipinfo -1 / tar -tf / 7z l)     — milliseconds
///   2. FILTER:  Match filenames against glob/regex pattern in-memory             — microseconds
///   3. CONTENT: Batch-extract matching files to temp dir, then grep locally      — seconds, not minutes
enum FindFilesArchiveSearcher {

    // MARK: - Main Entry Point

    @concurrent static func searchInsideArchive(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveSearchDelta {
        let ext = archiveURL.pathExtension.lowercased()
        let fileName = archiveURL.lastPathComponent.lowercased()

        // Determine archive type and get listing
        let listingResult: ArchiveListingResult

        switch ext {
        case "zip", "jar", "war", "ear", "aar", "apk":
            listingResult = await listZipContents(
                archiveURL: archiveURL, passwordCallback: passwordCallback)

        case "tar":
            listingResult = await listTarContents(archiveURL: archiveURL, compression: nil)

        case "gz", "gzip", "tgz":
            if fileName.hasSuffix(".tar.gz") || ext == "tgz" {
                listingResult = await listTarContents(archiveURL: archiveURL, compression: "-z")
            } else {
                listingResult = await listTarContents(archiveURL: archiveURL, compression: "-z")
            }

        case "bz2", "bzip2", "tbz", "tbz2":
            listingResult = await listTarContents(archiveURL: archiveURL, compression: "-j")

        case "xz", "txz":
            listingResult = await listTarContents(archiveURL: archiveURL, compression: "-J")

        case "z":
            listingResult = await listTarContents(archiveURL: archiveURL, compression: "-Z")

        case "lzma", "tlz", "zst", "zstd", "lz4", "lzo", "lz":
            // macOS tar with libarchive auto-detects these
            listingResult = await listTarContents(archiveURL: archiveURL, compression: nil)

        case "7z":
            listingResult = await list7zContents(
                archiveURL: archiveURL, passwordCallback: passwordCallback)

        default:
            // Fallback: try 7z for any recognized archive extension
            if ArchiveExtensions.isArchive(ext) {
                listingResult = await list7zContents(
                    archiveURL: archiveURL, passwordCallback: passwordCallback)
            } else {
                log.debug("[ArchiveSearcher] Unknown format, skipping: \(archiveURL.lastPathComponent)")
                return ArchiveSearchDelta()
            }
        }

        // Process listing: filter by name, optionally search content
        guard case .success(let entries) = listingResult else {
            if case .passwordRequired = listingResult {
                log.info("[ArchiveSearcher] Password required but not provided: \(archiveURL.lastPathComponent)")
            }
            return ArchiveSearchDelta()
        }

        guard !entries.isEmpty else { return ArchiveSearchDelta() }
        log.debug("[ArchiveSearcher] Listed \(entries.count) entries in \(archiveURL.lastPathComponent)")

        // Step 2: Filter entries by name pattern (in-memory, microseconds)
        let matchingEntries = entries.filter { entryPath in
            guard !Task.isCancelled else { return false }
            guard !entryPath.hasSuffix("/") else { return false }  // Skip directories
            let fileName = (entryPath as NSString).lastPathComponent
            return FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria)
        }

        guard !matchingEntries.isEmpty else { return ArchiveSearchDelta() }
        log.debug("[ArchiveSearcher] \(matchingEntries.count) entries match pattern in \(archiveURL.lastPathComponent)")

        // Step 3: Content search (if needed) or yield name-only results
        if let contentPattern, criteria.isContentSearch {
            return await batchContentSearch(
                archiveURL: archiveURL,
                matchingEntries: matchingEntries,
                contentPattern: contentPattern,
                continuation: continuation)
        } else {
            // Name-only search — yield all matching entries immediately
            var delta = ArchiveSearchDelta()
            for entryPath in matchingEntries {
                guard !Task.isCancelled else { return delta }
                let virtualURL = archiveURL.appendingPathComponent(entryPath)
                let result = FindFilesResult(
                    fileURL: virtualURL, isInsideArchive: true, archivePath: archiveURL.path)
                continuation.yield(result)
                delta.matchesFound += 1
            }
            return delta
        }
    }

    // MARK: - Listing Result

    private enum ArchiveListingResult: Sendable {
        case success([String])      // Array of entry paths (files and directories)
        case passwordRequired       // Archive is password-protected, no callback or user skipped
        case failed(String)         // Error message
    }

    // MARK: - ZIP Listing (zipinfo -1)
    // zipinfo -1 outputs one filename per line — clean, fast, no parsing needed
    // Benchmark: 304 MB ZIP with 16K entries → 33 ms

    @concurrent private static func listZipContents(
        archiveURL: URL,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveListingResult {
        // Try without password first
        let result = await runCLI(
            executable: "/usr/bin/zipinfo",
            arguments: ["-1", archiveURL.path])

        if result.exitCode == 0 {
            let entries = result.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            return .success(entries)
        }

        // Exit code != 0 — might be password-protected or corrupted
        guard let callback = passwordCallback else {
            log.warning("[ArchiveSearcher] zipinfo failed (exit \(result.exitCode)): \(archiveURL.lastPathComponent)")
            return .passwordRequired
        }

        log.info("[ArchiveSearcher] ZIP may be password-protected: \(archiveURL.lastPathComponent)")
        let response = await callback(archiveURL.lastPathComponent)

        switch response {
        case .password(let pwd):
            // zipinfo doesn't support passwords, use unzip -l -P instead
            let pwdResult = await runCLI(
                executable: "/usr/bin/unzip",
                arguments: ["-l", "-P", pwd, archiveURL.path])

            guard pwdResult.exitCode == 0 else {
                return .failed("Wrong password or corrupted archive")
            }
            return .success(parseUnzipListing(pwdResult.stdout))

        case .skip:
            return .passwordRequired
        }
    }

    // MARK: - TAR Listing (tar -tf)

    @concurrent private static func listTarContents(
        archiveURL: URL, compression: String?
    ) async -> ArchiveListingResult {
        var args: [String] = []
        if let comp = compression { args.append(comp) }
        args.append(contentsOf: ["-tf", archiveURL.path])

        let result = await runCLI(
            executable: "/usr/bin/tar",
            arguments: args)

        guard result.exitCode == 0 else {
            // Fallback to 7z
            log.warning("[ArchiveSearcher] tar failed, trying 7z fallback: \(archiveURL.lastPathComponent)")
            return await list7zContents(archiveURL: archiveURL, passwordCallback: nil)
        }

        let entries = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return .success(entries)
    }

    // MARK: - 7z Listing (7z l)

    @concurrent private static func list7zContents(
        archiveURL: URL,
        passwordCallback: ArchivePasswordCallback?
    ) async -> ArchiveListingResult {
        guard let szPath = find7z() else {
            log.warning("[ArchiveSearcher] 7z not found — skipping \(archiveURL.lastPathComponent)")
            return .failed("7z not installed")
        }

        let result = await runCLI(
            executable: szPath,
            arguments: ["l", archiveURL.path])

        if result.exitCode == 0 {
            return .success(parse7zListing(result.stdout))
        }

        // Password?
        guard let callback = passwordCallback else {
            return .passwordRequired
        }

        let response = await callback(archiveURL.lastPathComponent)
        switch response {
        case .password(let pwd):
            let pwdResult = await runCLI(
                executable: szPath,
                arguments: ["l", "-p\(pwd)", archiveURL.path])
            guard pwdResult.exitCode == 0 else {
                return .failed("Wrong password or corrupted")
            }
            return .success(parse7zListing(pwdResult.stdout))
        case .skip:
            return .passwordRequired
        }
    }

    // MARK: - Batch Content Search
    // Strategy: extract ALL matching files to temp dir at once, then grep locally.
    // This is 10x faster than extracting files one-by-one.
    // Benchmark: 7286 .java files → 3.2 s batch vs 31 s per-file

    @concurrent private static func batchContentSearch(
        archiveURL: URL,
        matchingEntries: [String],
        contentPattern: NSRegularExpression,
        continuation: AsyncStream<FindFilesResult>.Continuation
    ) async -> ArchiveSearchDelta {
        var delta = ArchiveSearchDelta()
        let ext = archiveURL.pathExtension.lowercased()

        // Create temp directory for batch extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMi_search_\(UUID().uuidString)", isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            log.error("[ArchiveSearcher] Cannot create temp dir: \(error)")
            return delta
        }

        // Batch extract matching files
        let extractOK: Bool

        switch ext {
        case "zip", "jar", "war", "ear", "aar", "apk":
            // unzip -o -q <archive> <file1> <file2> ... -d <tempDir>
            // For large file lists, write entries to a file list and use unzip @listfile
            extractOK = await batchExtractZip(
                archiveURL: archiveURL,
                entries: matchingEntries,
                destination: tempDir)

        case "7z":
            extractOK = await batchExtract7z(
                archiveURL: archiveURL,
                entries: matchingEntries,
                destination: tempDir)

        default:
            // For tar-based: extract specific files
            extractOK = await batchExtractTar(
                archiveURL: archiveURL,
                entries: matchingEntries,
                destination: tempDir)
        }

        guard extractOK else {
            log.warning("[ArchiveSearcher] Batch extraction failed: \(archiveURL.lastPathComponent)")
            return delta
        }

        // Search extracted files locally — fast sequential I/O
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return delta }

        while let fileURL = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { return delta }

            let rv = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard rv?.isRegularFile == true else { continue }
            guard FindFilesContentSearcher.isLikelyTextFile(url: fileURL) else { continue }

            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1)
            else { continue }

            // Reconstruct the virtual path: archive + relative path inside archive
            let relativePath = fileURL.path
                .replacingOccurrences(of: tempDir.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                guard !Task.isCancelled else { return delta }
                let range = NSRange(line.startIndex..., in: line)
                if contentPattern.firstMatch(in: line, range: range) != nil {
                    let virtualURL = archiveURL.appendingPathComponent(relativePath)
                    let result = FindFilesResult(
                        fileURL: virtualURL,
                        matchContext: String(line.prefix(200)),
                        lineNumber: index + 1,
                        isInsideArchive: true,
                        archivePath: archiveURL.path)
                    continuation.yield(result)
                    delta.matchesFound += 1
                }
            }
        }

        return delta
    }

    // MARK: - Batch Extract: ZIP

    @concurrent private static func batchExtractZip(
        archiveURL: URL, entries: [String], destination: URL
    ) async -> Bool {
        // Collect unique extensions from matching entries to build wildcard patterns
        // e.g., ["*.java", "*.xml"] — much faster than listing individual files
        let extensions = Set(entries.compactMap { entry -> String? in
            let ext = (entry as NSString).pathExtension.lowercased()
            return ext.isEmpty ? nil : ext
        })

        if !extensions.isEmpty && extensions.count <= 20 {
            // Use wildcard patterns: unzip -o archive '*.java' '*.xml' -d dest
            var args = ["-o", "-q", archiveURL.path]
            args.append(contentsOf: extensions.map { "*.\($0)" })
            args.append(contentsOf: ["-d", destination.path])

            let result = await runCLI(executable: "/usr/bin/unzip", arguments: args)
            if result.exitCode == 0 { return true }
            log.debug("[ArchiveSearcher] Wildcard extract failed, falling back to explicit list")
        }

        // Fallback: extract specific files in batches to avoid argument length limits
        // macOS ARG_MAX is ~262144 bytes; use conservative 200KB limit
        let maxArgLen = 200_000
        var currentBatch: [String] = []
        var currentLen = 0
        var allOK = true

        for entry in entries {
            currentLen += entry.utf8.count + 1  // +1 for space separator
            if currentLen > maxArgLen && !currentBatch.isEmpty {
                // Flush current batch
                if !(await extractZipBatch(archiveURL: archiveURL, entries: currentBatch, destination: destination)) {
                    allOK = false
                }
                currentBatch = []
                currentLen = entry.utf8.count + 1
            }
            currentBatch.append(entry)
        }

        // Flush remaining
        if !currentBatch.isEmpty {
            if !(await extractZipBatch(archiveURL: archiveURL, entries: currentBatch, destination: destination)) {
                allOK = false
            }
        }

        return allOK
    }

    @concurrent private static func extractZipBatch(
        archiveURL: URL, entries: [String], destination: URL
    ) async -> Bool {
        var args = ["-o", "-q", archiveURL.path]
        args.append(contentsOf: entries)
        args.append(contentsOf: ["-d", destination.path])
        let result = await runCLI(executable: "/usr/bin/unzip", arguments: args)
        return result.exitCode == 0
    }

    // MARK: - Batch Extract: TAR

    @concurrent private static func batchExtractTar(
        archiveURL: URL, entries: [String], destination: URL
    ) async -> Bool {
        let ext = archiveURL.pathExtension.lowercased()
        let fileName = archiveURL.lastPathComponent.lowercased()

        var args: [String] = ["-x"]
        // Add compression flag
        if fileName.hasSuffix(".tar.gz") || ext == "tgz" || ext == "gz" || ext == "gzip" {
            args.append("-z")
        } else if ext == "bz2" || ext == "bzip2" || ext == "tbz" || ext == "tbz2" {
            args.append("-j")
        } else if ext == "xz" || ext == "txz" {
            args.append("-J")
        } else if ext == "z" {
            args.append("-Z")
        }

        args.append(contentsOf: ["-f", archiveURL.path, "-C", destination.path])
        args.append(contentsOf: entries)

        let result = await runCLI(executable: "/usr/bin/tar", arguments: args)
        return result.exitCode == 0
    }

    // MARK: - Batch Extract: 7z

    @concurrent private static func batchExtract7z(
        archiveURL: URL, entries: [String], destination: URL
    ) async -> Bool {
        guard let szPath = find7z() else { return false }

        // 7z e <archive> -o<dest> <file1> <file2> ...  (-e extracts without paths)
        // 7z x <archive> -o<dest> <file1> <file2> ...  (-x extracts with paths)
        var args = ["x", archiveURL.path, "-o\(destination.path)", "-y"]
        args.append(contentsOf: entries)

        let result = await runCLI(executable: szPath, arguments: args)
        return result.exitCode == 0
    }

    // MARK: - Parsers

    /// Parse `unzip -l` output (fallback for password-protected ZIPs)
    /// Format: "  Length      Date    Time    Name"
    private static func parseUnzipListing(_ output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var entries: [String] = []
        var headerPassed = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("----") {
                headerPassed.toggle()
                continue
            }
            guard headerPassed else { continue }
            // unzip -l format: "  12345  01-15-2026 10:30   path/to/file.java"
            let components = trimmed.split(separator: " ", maxSplits: 3)
            guard components.count >= 4 else { continue }
            let entryName = String(components[3])
            entries.append(entryName)
        }
        return entries
    }

    /// Parse `7z l` output
    /// File entries appear between two "---" separator lines
    private static func parse7zListing(_ output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var entries: [String] = []
        var inFileList = false

        for line in lines {
            if line.hasPrefix("---") {
                inFileList.toggle()
                continue
            }
            guard inFileList else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // 7z l format: "Date Time Attr Size CSize Name"
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            let attrs = String(components[2])
            guard !attrs.hasPrefix("D") else { continue }  // Skip directories
            let entryName = components[5...].joined(separator: " ")
            entries.append(entryName)
        }
        return entries
    }

    // MARK: - CLI Runner

    private struct CLIResult: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    /// Run a CLI tool asynchronously with proper pipe handling
    @concurrent private static func runCLI(
        executable: String,
        arguments: [String],
        stdinFile: URL? = nil
    ) async -> CLIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdinFile {
            if let fh = FileHandle(forReadingAtPath: stdinFile.path) {
                process.standardInput = fh
            }
        }

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                continuation.resume(returning: CLIResult(
                    stdout: stdout, stderr: stderr, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: CLIResult(
                    stdout: "", stderr: error.localizedDescription, exitCode: -1))
            }
        }
    }

    // MARK: - Helpers

    private static func find7z() -> String? {
        ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }
}

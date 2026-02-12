// FindFilesEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Core async search engine — name, content, archive search with cancellation support

import Foundation

// MARK: - Search Result
/// Single search result representing a found file or content match
struct FindFilesResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    let fileName: String
    let filePath: String
    let matchContext: String?
    let lineNumber: Int?
    let isInsideArchive: Bool
    let archivePath: String?
    let fileSize: Int64
    let modifiedDate: Date?

    init(
        fileURL: URL,
        matchContext: String? = nil,
        lineNumber: Int? = nil,
        isInsideArchive: Bool = false,
        archivePath: String? = nil
    ) {
        self.id = UUID()
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.filePath = fileURL.path
        self.matchContext = matchContext
        self.lineNumber = lineNumber
        self.isInsideArchive = isInsideArchive
        self.archivePath = archivePath

        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path) {
            self.fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            self.modifiedDate = attrs[.modificationDate] as? Date
        } else {
            self.fileSize = 0
            self.modifiedDate = nil
        }
    }
}

// MARK: - Search Criteria
/// All parameters for a file search operation
struct FindFilesCriteria: Sendable {
    var searchDirectory: URL
    var fileNamePattern: String = "*"
    var searchText: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var searchInSubdirectories: Bool = true
    var searchInArchives: Bool = false
    var maxDepth: Int = 100
    var fileSizeMin: Int64? = nil
    var fileSizeMax: Int64? = nil
    var dateFrom: Date? = nil
    var dateTo: Date? = nil

    /// Whether we need content search (not just filename matching)
    var isContentSearch: Bool {
        !searchText.isEmpty
    }
}

// MARK: - Search Statistics
/// Running statistics about the current search
struct FindFilesStats: Sendable {
    var directoriesScanned: Int = 0
    var filesScanned: Int = 0
    var matchesFound: Int = 0
    var archivesScanned: Int = 0
    var startTime: Date = Date()
    var isRunning: Bool = false

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var formattedElapsed: String {
        let secs = Int(elapsedTime)
        if secs < 60 { return "\(secs)s" }
        let mins = secs / 60
        let rem = secs % 60
        return "\(mins)m \(rem)s"
    }
}

// MARK: - Archive Password Request
/// Callback type for requesting archive password from the user
typealias ArchivePasswordCallback = @concurrent @Sendable (String) async -> ArchivePasswordResponse

enum ArchivePasswordResponse: Sendable {
    case password(String)
    case skip
}

// MARK: - Find Files Engine
/// Async search engine that runs in background and streams results via AsyncStream.
/// Supports cancellation via Swift concurrency Task cancellation.
actor FindFilesEngine {

    private var currentTask: Task<Void, Never>?
    private(set) var stats = FindFilesStats()
    /// Use centralized ArchiveExtensions from ArchiveNavigationState
    private var archiveExtensions: Set<String> { ArchiveExtensions.all }

    // MARK: - Start Search
    /// Starts an async search returning results as an AsyncStream.
    /// The search runs in a background Task and can be cancelled.
    func search(
        criteria: FindFilesCriteria,
        passwordCallback: ArchivePasswordCallback? = nil
    ) -> AsyncStream<FindFilesResult> {
        // Cancel any running search
        currentTask?.cancel()
        stats = FindFilesStats()
        stats.isRunning = true
        stats.startTime = Date()

        let criteria = criteria
        let passwordCallback = passwordCallback
        return AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.performSearch(
                    criteria: criteria,
                    continuation: continuation,
                    passwordCallback: passwordCallback
                )
                continuation.finish()
                await self.markSearchComplete()
            }
            self.currentTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Cancel Search
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        stats.isRunning = false
    }

    // MARK: - Get Stats
    func getStats() -> FindFilesStats {
        stats
    }

    // MARK: - Private Implementation

    private func markSearchComplete() {
        stats.isRunning = false
    }

    private func performSearch(
        criteria: FindFilesCriteria,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        let fm = FileManager.default
        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let contentPattern = criteria.isContentSearch
            ? buildContentPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            : nil

        await scanDirectory(
            url: criteria.searchDirectory,
            depth: 0,
            criteria: criteria,
            nameRegex: nameRegex,
            contentPattern: contentPattern,
            continuation: continuation,
            passwordCallback: passwordCallback,
            fm: fm
        )
    }

    private func scanDirectory(
        url: URL,
        depth: Int,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        fm: FileManager
    ) async {
        // Check cancellation
        guard !Task.isCancelled else { return }
        guard depth <= criteria.maxDepth else { return }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return }

        // Collect URLs synchronously to avoid makeIterator() in async context
        var fileURLs: [(URL, URLResourceValues?)] = []
        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            let rv = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDir = rv?.isDirectory ?? false
            if isDir {
                stats.directoriesScanned += 1
                if !criteria.searchInSubdirectories {
                    enumerator.skipDescendants()
                }
                continue
            }
            fileURLs.append((fileURL, rv))
        }

        for (fileURL, resourceValues) in fileURLs {
            guard !Task.isCancelled else { return }

            stats.filesScanned += 1

            // Size filter
            if let minSize = criteria.fileSizeMin {
                let size = Int64(resourceValues?.fileSize ?? 0)
                if size < minSize { continue }
            }
            if let maxSize = criteria.fileSizeMax {
                let size = Int64(resourceValues?.fileSize ?? 0)
                if size > maxSize { continue }
            }

            // Date filter
            if let dateFrom = criteria.dateFrom, let modDate = resourceValues?.contentModificationDate {
                if modDate < dateFrom { continue }
            }
            if let dateTo = criteria.dateTo, let modDate = resourceValues?.contentModificationDate {
                if modDate > dateTo { continue }
            }

            let fileName = fileURL.lastPathComponent

            // Name matching
            let nameMatches = matchesName(fileName: fileName, regex: nameRegex, criteria: criteria)

            // Archive handling
            let ext = fileURL.pathExtension.lowercased()
            if criteria.searchInArchives && archiveExtensions.contains(ext) {
                stats.archivesScanned += 1
                log.debug("[FindFiles] Scanning archive: \(fileURL.lastPathComponent)")
                if criteria.isContentSearch {
                    await searchInsideArchive(
                        archiveURL: fileURL,
                        criteria: criteria,
                        contentPattern: contentPattern,
                        continuation: continuation,
                        passwordCallback: passwordCallback
                    )
                } else if nameMatches {
                    let result = FindFilesResult(fileURL: fileURL)
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
                continue
            }

            if criteria.isContentSearch {
                // Content search: name must match AND content must contain text
                if nameMatches {
                    let contentResults = await searchFileContent(
                        fileURL: fileURL,
                        pattern: contentPattern!
                    )
                    for result in contentResults {
                        guard !Task.isCancelled else { return }
                        continuation.yield(result)
                        stats.matchesFound += 1
                    }
                }
            } else {
                // Name-only search
                if nameMatches {
                    let result = FindFilesResult(fileURL: fileURL)
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            }

            // Yield control periodically to avoid blocking
            if stats.filesScanned % 100 == 0 {
                await Task.yield()
            }
        }
    }

    // MARK: - Name Matching

    private func matchesName(fileName: String, regex: NSRegularExpression?, criteria: FindFilesCriteria) -> Bool {
        if criteria.fileNamePattern.isEmpty || criteria.fileNamePattern == "*" || criteria.fileNamePattern == "*.*" {
            return true
        }
        guard let regex else { return true }
        let range = NSRange(fileName.startIndex..., in: fileName)
        return regex.firstMatch(in: fileName, range: range) != nil
    }

    private func buildNameRegex(pattern: String, caseSensitive: Bool) -> NSRegularExpression? {
        if pattern.isEmpty || pattern == "*" || pattern == "*.*" { return nil }

        // Convert glob pattern to regex
        var regexStr = "^"
        for char in pattern {
            switch char {
            case "*": regexStr += ".*"
            case "?": regexStr += "."
            case ".": regexStr += "\\."
            case "(", ")", "[", "]", "{", "}", "+", "^", "$", "|", "\\": regexStr += "\\\(char)"
            default: regexStr += String(char)
            }
        }
        regexStr += "$"

        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: regexStr, options: options)
    }

    // MARK: - Content Matching

    private func buildContentPattern(text: String, caseSensitive: Bool, useRegex: Bool) -> NSRegularExpression? {
        let pattern = useRegex ? text : NSRegularExpression.escapedPattern(for: text)
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    private func searchFileContent(fileURL: URL, pattern: NSRegularExpression) async -> [FindFilesResult] {
        var results: [FindFilesResult] = []

        // Only search text-readable files (skip binaries)
        guard isLikelyTextFile(url: fileURL) else { return results }

        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return results }

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            guard !Task.isCancelled else { break }
            let range = NSRange(line.startIndex..., in: line)
            if pattern.firstMatch(in: line, range: range) != nil {
                let contextLine = String(line.prefix(200))
                let result = FindFilesResult(
                    fileURL: fileURL,
                    matchContext: contextLine,
                    lineNumber: index + 1
                )
                results.append(result)
            }
        }
        return results
    }

    private func isLikelyTextFile(url: URL) -> Bool {
        let textExtensions: Set<String> = [
            "txt", "md", "swift", "java", "py", "js", "ts", "jsx", "tsx", "html", "htm",
            "css", "scss", "less", "xml", "json", "yaml", "yml", "toml", "ini", "cfg",
            "conf", "properties", "sh", "bash", "zsh", "fish", "bat", "cmd", "ps1",
            "c", "h", "cpp", "hpp", "cc", "cxx", "cs", "go", "rs", "rb", "php",
            "pl", "pm", "r", "scala", "kt", "kts", "gradle", "groovy", "lua",
            "sql", "graphql", "proto", "makefile", "cmake", "dockerfile",
            "gitignore", "gitattributes", "editorconfig", "env", "log", "csv", "tsv",
            "rtf", "tex", "bib", "rst", "adoc", "org", "vim", "el", "lisp", "clj",
            "erl", "ex", "exs", "hs", "ml", "mli", "fs", "fsx", "v", "sv",
            "vhd", "vhdl", "asm", "s", "d", "di", "nim", "zig", "plist", "strings",
            "storyboard", "xib", "xcconfig", "pbxproj", "xcscheme", "entitlements"
        ]
        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }
        // Files without extension might be text (Makefile, Dockerfile, etc.)
        if ext.isEmpty {
            let name = url.lastPathComponent.lowercased()
            let textNames: Set<String> = [
                "makefile", "dockerfile", "rakefile", "gemfile", "podfile",
                "brewfile", "procfile", "readme", "license", "changelog",
                "authors", "contributors", "todo", "copying"
            ]
            return textNames.contains(name)
        }
        return false
    }

    // MARK: - Archive Search

    private func searchInsideArchive(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        let ext = archiveURL.pathExtension.lowercased()
        let name = archiveURL.lastPathComponent.lowercased()

        switch ext {
        case "zip":
            await searchInsideZip(
                archiveURL: archiveURL,
                criteria: criteria,
                contentPattern: contentPattern,
                continuation: continuation,
                passwordCallback: passwordCallback
            )
        case "7z":
            await searchInside7z(
                archiveURL: archiveURL,
                criteria: criteria,
                contentPattern: contentPattern,
                continuation: continuation,
                passwordCallback: passwordCallback
            )
        case "tar", "tgz", "gz", "gzip", "bz2", "bzip2", "xz", "txz", "lzma", "tlz",
             "tbz", "tbz2", "z":
            await searchInsideTar(
                archiveURL: archiveURL,
                criteria: criteria,
                contentPattern: contentPattern,
                continuation: continuation
            )
        case "jar", "war", "ear", "aar", "apk":
            // Java/Android archives are ZIP-based
            await searchInsideZip(
                archiveURL: archiveURL,
                criteria: criteria,
                contentPattern: contentPattern,
                continuation: continuation,
                passwordCallback: passwordCallback
            )
        default:
            // All other formats — try 7z as universal fallback
            await searchInside7z(
                archiveURL: archiveURL,
                criteria: criteria,
                contentPattern: contentPattern,
                continuation: continuation,
                passwordCallback: passwordCallback
            )
        }
    }

    private func searchInsideZip(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        // Use unzip -l to list contents, unzip -p to extract to stdout
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
            log.error("Failed to list zip archive: \(archiveURL.path) — \(error)")
            return
        }

        if listProcess.terminationStatus != 0 {
            // Might be password-protected
            if let callback = passwordCallback {
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    await searchInsideZipWithPassword(
                        archiveURL: archiveURL,
                        password: pwd,
                        criteria: criteria,
                        contentPattern: contentPattern,
                        continuation: continuation
                    )
                case .skip:
                    return
                }
            }
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return }
            // Parse unzip -l output: "  12345  01-01-2024 12:00   path/to/file.txt"
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let components = trimmed.split(separator: " ", maxSplits: 3)
            guard components.count >= 4 else { continue }
            let entryName = String(components[3])
            guard !entryName.hasSuffix("/") else { continue } // skip directories

            let fileName = (entryName as NSString).lastPathComponent
            if matchesName(fileName: fileName, regex: nameRegex, criteria: criteria) {
                if let contentPattern, criteria.isContentSearch {
                    // Extract and search content
                    await searchZipEntryContent(
                        archiveURL: archiveURL,
                        entryName: entryName,
                        contentPattern: contentPattern,
                        continuation: continuation
                    )
                } else {
                    let virtualURL = archiveURL.appendingPathComponent(entryName)
                    let result = FindFilesResult(
                        fileURL: virtualURL,
                        isInsideArchive: true,
                        archivePath: archiveURL.path
                    )
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            }
        }
    }

    private func searchInsideZipWithPassword(
        archiveURL: URL,
        password: String,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
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

        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let components = trimmed.split(separator: " ", maxSplits: 3)
            guard components.count >= 4 else { continue }
            let entryName = String(components[3])
            guard !entryName.hasSuffix("/") else { continue }

            let fileName = (entryName as NSString).lastPathComponent
            if matchesName(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path
                )
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }

    private func searchZipEntryContent(
        archiveURL: URL,
        entryName: String,
        contentPattern: NSRegularExpression,
        continuation: AsyncStream<FindFilesResult>.Continuation
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
                    fileURL: virtualURL,
                    matchContext: String(line.prefix(200)),
                    lineNumber: index + 1,
                    isInsideArchive: true,
                    archivePath: archiveURL.path
                )
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }

    private func searchInside7z(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        // Find 7z binary
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

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
                let response = await callback(archiveURL.lastPathComponent)
                switch response {
                case .password(let pwd):
                    await searchInside7zWithPassword(
                        archiveURL: archiveURL,
                        password: pwd,
                        szPath: szPath,
                        criteria: criteria,
                        contentPattern: contentPattern,
                        continuation: continuation
                    )
                case .skip:
                    return
                }
            }
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        // Parse 7z l output — entries between "---" lines
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
            // 7z list format: "2024-01-01 12:00:00 D....    0    0  dirname" or "... .....  12345  12345  filename"
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            let attrs = String(components[2])
            guard !attrs.hasPrefix("D") else { continue } // skip directories
            let entryName = components[5...].joined(separator: " ")
            let fileName = (entryName as NSString).lastPathComponent

            if matchesName(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path
                )
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }

    private func searchInside7zWithPassword(
        archiveURL: URL,
        password: String,
        szPath: String,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
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

        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
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
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 6 else { continue }
            let attrs = String(components[2])
            guard !attrs.hasPrefix("D") else { continue }
            let entryName = components[5...].joined(separator: " ")
            let fileName = (entryName as NSString).lastPathComponent

            if matchesName(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path
                )
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }

    private func searchInsideTar(
        archiveURL: URL,
        criteria: FindFilesCriteria,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation
    ) async {
        let ext = archiveURL.pathExtension.lowercased()
        var args = ["-tf"]
        switch ext {
        case "gz", "tgz": args.insert("-z", at: 0)
        case "bz2": args.insert("-j", at: 0)
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
        } catch { return }

        guard listProcess.terminationStatus == 0 else { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let listing = String(data: data, encoding: .utf8) else { return }

        let nameRegex = buildNameRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let lines = listing.components(separatedBy: .newlines)

        for line in lines {
            guard !Task.isCancelled else { return }
            let entryName = line.trimmingCharacters(in: .whitespaces)
            guard !entryName.isEmpty, !entryName.hasSuffix("/") else { continue }
            let fileName = (entryName as NSString).lastPathComponent

            if matchesName(fileName: fileName, regex: nameRegex, criteria: criteria) {
                let virtualURL = archiveURL.appendingPathComponent(entryName)
                let result = FindFilesResult(
                    fileURL: virtualURL,
                    isInsideArchive: true,
                    archivePath: archiveURL.path
                )
                continuation.yield(result)
                stats.matchesFound += 1
            }
        }
    }
}

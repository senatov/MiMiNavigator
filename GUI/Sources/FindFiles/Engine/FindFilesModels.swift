// FindFilesModels.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Data models for Find Files — result, criteria, statistics, password callback

import Foundation

// MARK: - Search Result
/// Single search result representing a found file or content match
struct FindFilesResult: Identifiable, Hashable, Sendable, Codable {
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

    // MARK: - Codable support
    enum CodingKeys: String, CodingKey {
        case id, fileURLString, fileName, filePath
        case matchContext, lineNumber
        case isInsideArchive, archivePath
        case fileSize, modifiedDate
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fileURL.absoluteString, forKey: .fileURLString)
        try c.encode(fileName, forKey: .fileName)
        try c.encode(filePath, forKey: .filePath)
        try c.encodeIfPresent(matchContext, forKey: .matchContext)
        try c.encodeIfPresent(lineNumber, forKey: .lineNumber)
        try c.encode(isInsideArchive, forKey: .isInsideArchive)
        try c.encodeIfPresent(archivePath, forKey: .archivePath)
        try c.encode(fileSize, forKey: .fileSize)
        try c.encodeIfPresent(modifiedDate, forKey: .modifiedDate)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        let urlString = try c.decode(String.self, forKey: .fileURLString)
        fileURL = URL(string: urlString) ?? URL(fileURLWithPath: urlString)
        fileName = try c.decode(String.self, forKey: .fileName)
        filePath = try c.decode(String.self, forKey: .filePath)
        matchContext = try c.decodeIfPresent(String.self, forKey: .matchContext)
        lineNumber = try c.decodeIfPresent(Int.self, forKey: .lineNumber)
        isInsideArchive = try c.decode(Bool.self, forKey: .isInsideArchive)
        archivePath = try c.decodeIfPresent(String.self, forKey: .archivePath)
        fileSize = try c.decode(Int64.self, forKey: .fileSize)
        modifiedDate = try c.decodeIfPresent(Date.self, forKey: .modifiedDate)
    }

    init(
        fileURL: URL,
        matchContext: String? = nil,
        lineNumber: Int? = nil,
        isInsideArchive: Bool = false,
        archivePath: String? = nil,
        knownSize: Int64? = nil
    ) {
        self.id = UUID()
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.filePath = fileURL.path
        self.matchContext = matchContext
        self.lineNumber = lineNumber
        self.isInsideArchive = isInsideArchive
        self.archivePath = archivePath

        // Skip stat() for virtual paths inside archives — the file doesn't exist on disk
        if isInsideArchive {
            self.fileSize = knownSize ?? 0
            self.modifiedDate = nil
        } else {
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

    /// If true, searchDirectory is a single archive file (not a directory).
    /// Engine should search only inside that archive.
    var isArchiveOnlySearch: Bool = false

    /// If true, searchDirectory is a single regular file — search its text content.
    var isSingleFileContentSearch: Bool = false

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
    /// Currently scanned path (for progress display)
    var currentPath: String = ""

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

// MARK: - Scanned File Entry
/// Sendable snapshot of file metadata — replaces non-Sendable URLResourceValues in async loops
struct ScannedFileEntry: Sendable {
    let url: URL
    let fileSize: Int64
    let modificationDate: Date?
}

// MARK: - Archive Password Request
/// Callback type for requesting archive password from the user
typealias ArchivePasswordCallback = @concurrent @Sendable (String) async -> ArchivePasswordResponse

enum ArchivePasswordResponse: Sendable {
    case password(String)
    case skip
}

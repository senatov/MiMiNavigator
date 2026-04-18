// SafeJSONStorage.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared atomic JSON read/write with verification, periodic backups,
//   and fallback recovery from ~/.mimi/backup when the primary file is unreadable.

import Foundation

enum SafeJSONStorage {
    private static let backupDirectoryName = "backup"
    private static let backupInterval: TimeInterval = 5 * 60
    private static let maxBackupsPerFile = 36

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    static func loadCodable<T: Decodable>(
        from fileURL: URL,
        as type: T.Type,
        label: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(T.self, from: data)
        } catch {
            log.warning("[SafeJSONStorage] \(label) primary load failed: \(error.localizedDescription)")
        }

        guard let backupURL = latestBackupURL(for: fileURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let backupData = try Data(contentsOf: backupURL)
        let decoded = try decoder.decode(T.self, from: backupData)
        log.warning("[SafeJSONStorage] \(label) recovered from backup \(backupURL.lastPathComponent)")
        return decoded
    }

    static func writeCodable<T: Codable>(
        _ value: T,
        to fileURL: URL,
        label: String,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        let data = try encoder.encode(value)
        _ = try decoder.decode(T.self, from: data)
        try writeVerifiedData(data, to: fileURL, label: label) { writtenData in
            _ = try decoder.decode(T.self, from: writtenData)
        }
    }

    static func loadJSONObject(from fileURL: URL, label: String) throws -> [String: Any] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decodeJSONObject(data)
        } catch {
            log.warning("[SafeJSONStorage] \(label) primary load failed: \(error.localizedDescription)")
        }

        guard let backupURL = latestBackupURL(for: fileURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let backupData = try Data(contentsOf: backupURL)
        let decoded = try decodeJSONObject(backupData)
        log.warning("[SafeJSONStorage] \(label) recovered from backup \(backupURL.lastPathComponent)")
        return decoded
    }

    static func writeJSONObject(
        _ object: [String: Any],
        to fileURL: URL,
        label: String,
        options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        _ = try decodeJSONObject(data)
        try writeVerifiedData(data, to: fileURL, label: label) { writtenData in
            _ = try decodeJSONObject(writtenData)
        }
    }

    private static func writeVerifiedData(
        _ data: Data,
        to fileURL: URL,
        label: String,
        verifier: (Data) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let temporaryURL = directoryURL.appendingPathComponent(".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            let writtenData = try Data(contentsOf: temporaryURL)
            try verifier(writtenData)

            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }

            try writeBackupIfDue(data: data, for: fileURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            log.error("[SafeJSONStorage] \(label) write failed: \(error.localizedDescription)")
            throw error
        }
    }

    private static func decodeJSONObject(_ data: Data) throws -> [String: Any] {
        guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return decoded
    }

    private static func writeBackupIfDue(data: Data, for fileURL: URL) throws {
        guard shouldWriteBackup(for: fileURL) else { return }

        let backupDirURL = backupDirectoryURL(for: fileURL)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: backupDirURL, withIntermediateDirectories: true)

        let timestamp = timestampFormatter.string(from: Date())
        let backupURL = backupDirURL.appendingPathComponent("\(fileURL.deletingPathExtension().lastPathComponent)-\(timestamp).json")
        try data.write(to: backupURL, options: .atomic)
        try pruneOldBackups(for: fileURL)
    }

    private static func shouldWriteBackup(for fileURL: URL) -> Bool {
        guard let latestBackupURL = latestBackupURL(for: fileURL) else { return true }
        guard let values = try? latestBackupURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modifiedAt = values.contentModificationDate else {
            return true
        }
        return Date().timeIntervalSince(modifiedAt) >= backupInterval
    }

    private static func latestBackupURL(for fileURL: URL) -> URL? {
        let prefix = backupPrefix(for: fileURL)
        let backupDirURL = backupDirectoryURL(for: fileURL)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: backupDirURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .first
    }

    private static func pruneOldBackups(for fileURL: URL) throws {
        let prefix = backupPrefix(for: fileURL)
        let backupDirURL = backupDirectoryURL(for: fileURL)
        let urls = try FileManager.default.contentsOfDirectory(
            at: backupDirURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let matching = urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        guard matching.count > maxBackupsPerFile else { return }
        for url in matching.dropFirst(maxBackupsPerFile) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func backupDirectoryURL(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appendingPathComponent(backupDirectoryName, isDirectory: true)
    }

    private static func backupPrefix(for fileURL: URL) -> String {
        "\(fileURL.deletingPathExtension().lastPathComponent)-"
    }
}

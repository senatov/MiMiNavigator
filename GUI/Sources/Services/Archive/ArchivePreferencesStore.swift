import SwiftUI

// MARK: - Archive Preferences Store

/// Manages archive preferences — last format, compression levels, destination mode
/// Stored in ~/.mimi/archive_prefs.json
@MainActor
final class ArchivePreferencesStore: ObservableObject {
    static let shared = ArchivePreferencesStore()

    private let storageDirectoryURL: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private let fileURL: URL

    // MARK: - Published State

    /// Last selected archive format
    @Published var lastFormat: ArchiveFormat = .zip

    /// Destination mode for pack dialog
    @Published var destinationMode: DestinationMode = .currentPanel

    /// Custom destination path (when mode = .custom)
    @Published var customDestination: String = ""

    /// Per-format preferences
    @Published var formatPrefs: [String: ArchiveFormatPrefs] = [:]

    /// Whether to use Keychain for passwords
    @Published var useKeychainPasswords: Bool = true

    /// Delete source files after archiving
    @Published var deleteSourceFiles: Bool = false

    /// Use password encryption (per-session, not saved for security)
    @Published var usePassword: Bool = false

    /// Last used archive name prefix (optional)
    @Published var lastArchivePrefix: String = ""

    private init() {
        fileURL = storageDirectoryURL.appendingPathComponent("archive_prefs.json")
        ensureStoreFileExists()
        load()
    }

    // MARK: - Storage Helpers
    private func ensureStorageDirectoryExists() {
        do {
            try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[ArchivePrefs] failed to create storage directory: \(error)")
        }
    }

    private func ensureStoreFileExists() {
        ensureStorageDirectoryExists()
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let defaults = StoredData(
            lastFormat: lastFormat.rawValue,
            destinationMode: destinationMode.rawValue,
            customDestination: customDestination,
            formatPrefs: formatPrefs,
            useKeychainPasswords: useKeychainPasswords,
            usePassword: usePassword,
            deleteSourceFiles: deleteSourceFiles,
            lastArchivePrefix: nil
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(defaults)
            try json.write(to: fileURL, options: .atomic)
            log.info("[ArchivePrefs] created default archive_prefs.json")
        } catch {
            log.error("[ArchivePrefs] failed to create default prefs: \(error)")
        }
    }

    // MARK: - Destination Mode

    enum DestinationMode: String, Codable, CaseIterable {
        case currentPanel = "current"
        case oppositePanel = "opposite"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .currentPanel:  return "Current directory"
            case .oppositePanel: return "Opposite panel"
            case .custom:        return "Custom location"
            }
        }

        var icon: String {
            switch self {
            case .currentPanel:  return "folder"
            case .oppositePanel: return "arrow.left.arrow.right"
            case .custom:        return "folder.badge.gearshape"
            }
        }
    }

    // MARK: - Per-Format Access

    func prefs(for format: ArchiveFormat) -> ArchiveFormatPrefs {
        formatPrefs[format.rawValue] ?? ArchiveFormatPrefs()
    }

    func setPrefs(_ prefs: ArchiveFormatPrefs, for format: ArchiveFormat) {
        formatPrefs[format.rawValue] = prefs
        save()
    }

    func compressionLevel(for format: ArchiveFormat) -> CompressionLevel {
        prefs(for: format).compressionLevel
    }

    func setCompressionLevel(_ level: CompressionLevel, for format: ArchiveFormat) {
        var p = prefs(for: format)
        p.compressionLevel = level
        setPrefs(p, for: format)
    }

    // MARK: - Compression Support

    /// Whether format supports compression level selection
    func supportsCompression(_ format: ArchiveFormat) -> Bool {
        switch format {
        case .zip, .gzip, .bzip2, .xz, .lzma, .zstd, .lz4, .lzo, .lzip,
             .sevenZip, .tarGz, .tarBz2, .tarXz, .tarZst, .tarLz4:
            return true
        case .tar, .compressZ, .tarLzma, .tarLzo, .tarLz, .sevenZipGeneric:
            return false
        }
    }

    /// Whether format supports password protection
    func supportsPassword(_ format: ArchiveFormat) -> Bool {
        switch format {
        case .zip, .sevenZip:
            return true
        default:
            return false
        }
    }

    // MARK: - Persistence

    private struct StoredData: Codable {
        var lastFormat: String
        var destinationMode: String
        var customDestination: String
        var formatPrefs: [String: ArchiveFormatPrefs]
        var useKeychainPasswords: Bool
        var usePassword: Bool?
        var deleteSourceFiles: Bool?
        var lastArchivePrefix: String?
    }

    func save() {
        ensureStorageDirectoryExists()
        let data = StoredData(
            lastFormat: lastFormat.rawValue,
            destinationMode: destinationMode.rawValue,
            customDestination: customDestination,
            formatPrefs: formatPrefs,
            useKeychainPasswords: useKeychainPasswords,
            usePassword: usePassword,
            deleteSourceFiles: deleteSourceFiles,
            lastArchivePrefix: lastArchivePrefix.isEmpty ? nil : lastArchivePrefix
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(data)
            try json.write(to: fileURL)
            log.debug("[ArchivePrefs] saved to \(fileURL.path)")
        } catch {
            log.error("[ArchivePrefs] save failed: \(error)")
        }
    }

    private func load() {
        ensureStoreFileExists()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.debug("[ArchivePrefs] no saved prefs, using defaults")
            return
        }
        do {
            let json = try Data(contentsOf: fileURL)
            let data = try JSONDecoder().decode(StoredData.self, from: json)

            if let fmt = ArchiveFormat(rawValue: data.lastFormat) {
                lastFormat = fmt
            }
            if let mode = DestinationMode(rawValue: data.destinationMode) {
                destinationMode = mode
            }
            customDestination = data.customDestination
            formatPrefs = data.formatPrefs
            useKeychainPasswords = data.useKeychainPasswords
            usePassword = data.usePassword ?? false
            deleteSourceFiles = data.deleteSourceFiles ?? false
            lastArchivePrefix = data.lastArchivePrefix ?? ""

            log.debug("[ArchivePrefs] loaded: format=\(lastFormat) mode=\(destinationMode) deleteSource=\(deleteSourceFiles)")
        } catch {
            log.error("[ArchivePrefs] load failed: \(error)")
            formatPrefs = [:]
            usePassword = false
            deleteSourceFiles = false
            lastArchivePrefix = ""
        }
    }

    // MARK: - Update & Save

    func updateLastFormat(_ format: ArchiveFormat) {
        lastFormat = format
        save()
    }

    func updateDestinationMode(_ mode: DestinationMode) {
        destinationMode = mode
        save()
    }

    func updateCustomDestination(_ path: String) {
        customDestination = path
        save()
    }

    func updateDeleteSourceFiles(_ value: Bool) {
        deleteSourceFiles = value
        save()
    }

    func updateUseKeychainPasswords(_ value: Bool) {
        useKeychainPasswords = value
        save()
    }

    func updateUsePassword(_ value: Bool) {
        usePassword = value
        save()
    }
}

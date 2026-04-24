// RemoteServerKeychain.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Credential helpers for remote server passwords.
//   Passwords are stored in Keychain in all builds.
//   Keychain failures are logged with readable status details.

import Foundation
import LocalAuthentication
import Security

// MARK: - RemoteServerKeychain

@MainActor
enum RemoteServerKeychain {

    private struct PasswordIndexEntry: Codable {
        let endpointKey: String
        let hasPassword: Bool
        let updatedAt: Date
        let lastLoadAt: Date?
        let lastError: String?
    }

    private struct PasswordIndexFile: Codable {
        let version: Int
        var entries: [String: PasswordIndexEntry]
    }

    private static var runtimePasswordCache: [String: String] = [:]
    private static let passwordIndexVersion = 2
    private static let passwordIndexFileName = "remote-password-index.json"
}

// MARK: - Paths
extension RemoteServerKeychain {

    static func passwordIndexDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
            .appendingPathComponent("remote", isDirectory: true)
    }

    static func passwordIndexFileURL() -> URL {
        passwordIndexDirectoryURL().appendingPathComponent(passwordIndexFileName, isDirectory: false)
    }

    static func ensurePasswordIndexDirectoryExists() {
        let directoryURL = passwordIndexDirectoryURL()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[Keychain] failed to create password index directory at '\(directoryURL.path)': \(error.localizedDescription)")
        }
    }
}

extension RemoteServerKeychain {

    static func bootstrapPasswordIndexFileIfNeeded() {
        ensurePasswordIndexDirectoryExists()

        let fileURL = passwordIndexFileURL()
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let emptyFile = PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(emptyFile)
            try data.write(to: fileURL, options: .atomic)
            log.info("[Keychain] created password index at '\(fileURL.path)'")
        } catch {
            log.error("[Keychain] failed to bootstrap password index at '\(fileURL.path)': \(error.localizedDescription)")
        }
    }

    private static func loadPasswordIndexFile() -> PasswordIndexFile {
        bootstrapPasswordIndexFileIfNeeded()

        let fileURL = passwordIndexFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(PasswordIndexFile.self, from: data)
            return file.version == passwordIndexVersion
                ? file
                : PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        } catch {
            log.error("[Keychain] failed to read password index at '\(fileURL.path)': \(error.localizedDescription)")
            return PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        }
    }

    private static func savePasswordIndexFile(_ file: PasswordIndexFile) {
        bootstrapPasswordIndexFileIfNeeded()
        ensurePasswordIndexDirectoryExists()

        let fileURL = passwordIndexFileURL()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: .atomic)
            log.debug("[Keychain] updated password index at '\(fileURL.path)'")
        } catch {
            log.error("[Keychain] failed to write password index at '\(fileURL.path)': \(error.localizedDescription)")
        }
    }

    static func updatePasswordIndex(for server: RemoteServer, hasPassword: Bool, lastLoadAt: Date? = nil, lastError: String? = nil) {
        let key = endpointKey(for: server)
        var file = loadPasswordIndexFile()
        file.entries[key] = PasswordIndexEntry(
            endpointKey: key,
            hasPassword: hasPassword,
            updatedAt: Date(),
            lastLoadAt: lastLoadAt,
            lastError: lastError
        )
        savePasswordIndexFile(file)
    }

    static func removePasswordIndex(for server: RemoteServer) {
        let key = endpointKey(for: server)
        var file = loadPasswordIndexFile()
        if file.entries.removeValue(forKey: key) != nil {
            savePasswordIndexFile(file)
        }
    }

    static func logPasswordIndexState(for server: RemoteServer) {
        let key = endpointKey(for: server)
        let indexFile = loadPasswordIndexFile()

        if let entry = indexFile.entries[key] {
            log.debug(
                "[Keychain] password index hit for \(endpointDescription(for: server)) hasPassword=\(entry.hasPassword) updatedAt=\(entry.updatedAt)"
            )
        } else {
            log.debug("[Keychain] password index miss for \(endpointDescription(for: server))")
        }
    }
}

extension RemoteServerKeychain {

    static func cachedPassword(for server: RemoteServer) -> String? {
        runtimePasswordCache[endpointKey(for: server)]
    }

    static func cachePassword(_ password: String, for server: RemoteServer) {
        runtimePasswordCache[endpointKey(for: server)] = password
        log.debug("[Keychain] runtime cache updated for \(endpointDescription(for: server))")
    }

    static func removeCachedPassword(for server: RemoteServer) {
        let removed = runtimePasswordCache.removeValue(forKey: endpointKey(for: server)) != nil
        log.debug("[Keychain] runtime cache removed for \(endpointDescription(for: server)) removed=\(removed)")
    }
}

// MARK: - Keychain Queries

extension RemoteServerKeychain {

    static func passwordWriteQuery(_ password: String, for server: RemoteServer) -> [CFString: Any] {
        [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecAttrAccessible: keychainAccessibility(),
            kSecValueData: Data(password.utf8),
            kSecAttrLabel: keychainLabel(for: server),
        ]
    }

    static func passwordReadQuery(for server: RemoteServer) -> [CFString: Any] {
        let authContext = nonInteractiveAuthenticationContext()
        return [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: authContext,
            kSecUseAuthenticationUI: kSecUseAuthenticationUIFail,
        ]
    }

    static func passwordDeleteQuery(for server: RemoteServer) -> [CFString: Any] {
        let authContext = nonInteractiveAuthenticationContext()
        return [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecUseAuthenticationContext: authContext,
            kSecUseAuthenticationUI: kSecUseAuthenticationUIFail,
        ]
    }
}

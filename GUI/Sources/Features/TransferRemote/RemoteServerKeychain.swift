// RemoteServerKeychain.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Credential helpers for remote server passwords.
//   Passwords are stored in Keychain in all builds.
//   Keychain failures are logged with readable status details.

import Foundation
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
    private static let passwordIndexVersion = 1
    private static let passwordIndexFileName = "remote-password-index.json"

    private static func keychainLabel(for server: RemoteServer) -> String {
        "MiMiNavigator-Remote: \(server.host):\(server.port)"
    }

    private static func endpointKey(for server: RemoteServer) -> String {
        let host = server.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let user = server.user.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = server.remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(server.remoteProtocol.rawValue)|\(host)|\(server.port)|\(user)|\(path)"
    }

    private static func passwordIndexDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
            .appendingPathComponent("remote", isDirectory: true)
    }

    private static func passwordIndexFileURL() -> URL {
        passwordIndexDirectoryURL().appendingPathComponent(passwordIndexFileName, isDirectory: false)
    }

    private static func ensurePasswordIndexDirectoryExists() {
        let directoryURL = passwordIndexDirectoryURL()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[Keychain] failed to create password index directory at '\(directoryURL.path)': \(error.localizedDescription)")
        }
    }

    private static func loadPasswordIndexFile() -> PasswordIndexFile {
        let fileURL = passwordIndexFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(PasswordIndexFile.self, from: data)
            return file.version == passwordIndexVersion ? file : PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        } catch {
            log.error("[Keychain] failed to read password index at '\(fileURL.path)': \(error.localizedDescription)")
            return PasswordIndexFile(version: passwordIndexVersion, entries: [:])
        }
    }

    private static func savePasswordIndexFile(_ file: PasswordIndexFile) {
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

    private static func updatePasswordIndex(for server: RemoteServer, hasPassword: Bool, lastLoadAt: Date? = nil, lastError: String? = nil) {
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

    private static func removePasswordIndex(for server: RemoteServer) {
        let key = endpointKey(for: server)
        var file = loadPasswordIndexFile()
        if file.entries.removeValue(forKey: key) != nil {
            savePasswordIndexFile(file)
        }
    }

    private static func cachedPassword(for server: RemoteServer) -> String? {
        runtimePasswordCache[endpointKey(for: server)]
    }

    private static func cachePassword(_ password: String, for server: RemoteServer) {
        runtimePasswordCache[endpointKey(for: server)] = password
        log.debug("[Keychain] runtime cache updated for \(endpointDescription(for: server))")
    }

    private static func removeCachedPassword(for server: RemoteServer) {
        let removed = runtimePasswordCache.removeValue(forKey: endpointKey(for: server)) != nil
        log.debug("[Keychain] runtime cache removed for \(endpointDescription(for: server)) removed=\(removed)")
    }

    private static func endpointDescription(for server: RemoteServer) -> String {
        "\(server.remoteProtocol.rawValue.uppercased())://\(server.user)@\(server.host):\(server.port)"
    }

    private static func statusDescription(_ status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Unknown OSStatus"
    }

    private static func logKeychainFailure(_ action: String, status: OSStatus, server: RemoteServer) {
        log.error("[Keychain] \(action) failed for \(endpointDescription(for: server)) status=\(status) message='\(statusDescription(status))'")
    }

    static func savePassword(_ password: String, for server: RemoteServer) {
        guard !password.isEmpty else {
            log.warning("[Keychain] save skipped for \(endpointDescription(for: server)) because password is empty")
            return
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecValueData: Data(password.utf8),
            kSecAttrLabel: keychainLabel(for: server),
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logKeychainFailure("delete-before-save", status: deleteStatus, server: server)
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[Keychain] saved password for \(endpointDescription(for: server))")
            cachePassword(password, for: server)
            updatePasswordIndex(for: server, hasPassword: true)
        } else {
            logKeychainFailure("save", status: status, server: server)
            updatePasswordIndex(for: server, hasPassword: false, lastError: "save failed: \(statusDescription(status))")
        }
    }

    static func loadPassword(for server: RemoteServer) -> String {
        if let cachedPassword = cachedPassword(for: server) {
            log.debug("[Keychain] loaded password from runtime cache for \(endpointDescription(for: server))")
            return cachedPassword
        }

        let key = endpointKey(for: server)
        let indexFile = loadPasswordIndexFile()
        if let entry = indexFile.entries[key] {
            log.debug(
                "[Keychain] password index hit for \(endpointDescription(for: server)) hasPassword=\(entry.hasPassword) updatedAt=\(entry.updatedAt)"
            )
        } else {
            log.debug("[Keychain] password index miss for \(endpointDescription(for: server))")
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                log.info("[Keychain] no saved password for \(endpointDescription(for: server))")
                removeCachedPassword(for: server)
                updatePasswordIndex(for: server, hasPassword: false, lastError: nil)
            } else {
                logKeychainFailure("load", status: status, server: server)
                updatePasswordIndex(for: server, hasPassword: false, lastError: "load failed: \(statusDescription(status))")
            }
            return ""
        }

        guard let data = item as? Data else {
            log.error("[Keychain] load returned unexpected payload for \(endpointDescription(for: server))")
            updatePasswordIndex(for: server, hasPassword: false, lastError: "unexpected payload")
            return ""
        }

        guard let password = String(data: data, encoding: .utf8) else {
            log.error("[Keychain] load returned non-UTF8 password data for \(endpointDescription(for: server))")
            updatePasswordIndex(for: server, hasPassword: false, lastError: "non-UTF8 payload")
            return ""
        }

        cachePassword(password, for: server)
        updatePasswordIndex(for: server, hasPassword: true, lastLoadAt: Date())
        log.debug("[Keychain] loaded password for \(endpointDescription(for: server))")
        return password
    }

    static func deletePassword(for server: RemoteServer) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            log.info("[Keychain] deleted password for \(endpointDescription(for: server))")
            removeCachedPassword(for: server)
            removePasswordIndex(for: server)
        } else if status == errSecItemNotFound {
            log.info("[Keychain] delete skipped, no saved password for \(endpointDescription(for: server))")
            removeCachedPassword(for: server)
            removePasswordIndex(for: server)
        } else {
            logKeychainFailure("delete", status: status, server: server)
            updatePasswordIndex(for: server, hasPassword: false, lastError: "delete failed: \(statusDescription(status))")
        }
    }

    private static func protocolAttr(_ proto: RemoteProtocol) -> CFString {
        switch proto {
        case .sftp:
            return kSecAttrProtocolSSH
        case .ftp:
            return kSecAttrProtocolFTP
        case .smb:
            return kSecAttrProtocolSMB
        case .afp:
            return kSecAttrProtocolAFP
        }
    }
}

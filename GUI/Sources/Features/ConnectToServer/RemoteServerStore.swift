// RemoteServerStore.swift
// MiMiNavigator
//
// Created by Claude — 23.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistence for saved remote server bookmarks.
//   Servers stored as JSON in Application Support. Passwords in Keychain.

import Foundation
import Security

// MARK: - Store for saved servers (JSON file)
@MainActor
@Observable
final class RemoteServerStore {

    static let shared = RemoteServerStore()

    private(set) var servers: [RemoteServer] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("remote_servers.json")
    }()

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(_ server: RemoteServer) {
        servers.append(server)
        save()
        log.info("[RemoteStore] added '\(server.displayName)'")
    }

    func update(_ server: RemoteServer) {
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
            save()
            log.info("[RemoteStore] updated '\(server.displayName)'")
        }
    }

    func remove(_ server: RemoteServer) {
        servers.removeAll { $0.id == server.id }
        RemoteServerKeychain.deletePassword(for: server)
        save()
        log.info("[RemoteStore] removed '\(server.displayName)'")
    }

    func remove(at offsets: IndexSet) {
        for idx in offsets {
            RemoteServerKeychain.deletePassword(for: servers[idx])
        }
        servers.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            servers = try JSONDecoder().decode([RemoteServer].self, from: data)
            log.info("[RemoteStore] loaded \(servers.count) servers")
        } catch {
            log.error("[RemoteStore] load failed: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("[RemoteStore] save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Keychain helper for server passwords
enum RemoteServerKeychain {

    private static func keychainLabel(for server: RemoteServer) -> String {
        "MiMiNavigator-Remote: \(server.host):\(server.port)"
    }

    static func savePassword(_ password: String, for server: RemoteServer) {
        guard !password.isEmpty else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassInternetPassword,
            kSecAttrServer:  server.host,
            kSecAttrPort:    server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecValueData:   Data(password.utf8),
            kSecAttrLabel:   keychainLabel(for: server),
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[RemoteKeychain] saved password for \(server.host):\(server.port)")
        } else {
            log.warning("[RemoteKeychain] save failed: \(status)")
        }
    }

    static func loadPassword(for server: RemoteServer) -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassInternetPassword,
            kSecAttrServer:       server.host,
            kSecAttrPort:         server.port,
            kSecAttrAccount:      server.user,
            kSecAttrProtocol:     protocolAttr(server.remoteProtocol),
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return "" }
        return password
    }

    static func deletePassword(for server: RemoteServer) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassInternetPassword,
            kSecAttrServer:  server.host,
            kSecAttrPort:    server.port,
            kSecAttrAccount: server.user,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func protocolAttr(_ proto: RemoteProtocol) -> CFString {
        switch proto {
        case .sftp: return kSecAttrProtocolSSH
        case .ftp:  return kSecAttrProtocolFTP
        case .smb:  return kSecAttrProtocolSMB
        case .afp:  return kSecAttrProtocolAFP
        }
    }
}

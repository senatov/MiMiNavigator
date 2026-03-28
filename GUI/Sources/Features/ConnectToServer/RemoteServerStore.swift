// RemoteServerStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistence for saved remote server bookmarks.
//   Servers stored as JSON in Application Support. Passwords in Keychain.

import Foundation

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

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

    private let storageDirectoryURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
    }()

    private let fileURL: URL

    private func ensureStorageExists() {
        do {
            try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[RemoteStore] failed to create storage directory: \(error.localizedDescription)")
        }
    }

    private init() {
        fileURL = storageDirectoryURL.appendingPathComponent("remote_servers.json")
        ensureStorageExists()
        load()
    }

    // MARK: - Storage Helpers
    private func writeServersToDisk(_ servers: [RemoteServer]) {
        ensureStorageExists()
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("[RemoteStore] save failed: \(error.localizedDescription)")
        }
    }

    private func ensureStoreFileExists() {
        ensureStorageExists()
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        writeServersToDisk([])
        log.info("[RemoteStore] created default remote_servers.json")
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
        for index in offsets {
            RemoteServerKeychain.deletePassword(for: servers[index])
        }
        servers.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func load() {
        ensureStoreFileExists()

        do {
            let data = try Data(contentsOf: fileURL)
            servers = try JSONDecoder().decode([RemoteServer].self, from: data)
            log.info("[RemoteStore] loaded \(servers.count) servers")
        } catch {
            log.error("[RemoteStore] load failed: \(error.localizedDescription)")
            servers = []
            writeServersToDisk([])
            log.info("[RemoteStore] reset remote_servers.json to defaults")
        }
    }

    private func save() {
        writeServersToDisk(servers)
    }
}

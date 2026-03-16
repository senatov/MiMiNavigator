    // ColumnLayoutStore.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 20.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Singleton store holding column layouts for both panels.
    //              Loaded ONCE at startup.

    import FileModelKit
    import SwiftUI

    // MARK: - ColumnLayoutStore
    @MainActor
    @Observable
    final class ColumnLayoutStore {
        static let shared = ColumnLayoutStore()

        private nonisolated static let layoutFileURL: URL = {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".mimi", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir.appendingPathComponent("column_layout.json")
        }()

        private nonisolated static func writeSnapshot(_ snapshot: LayoutSnapshot) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: layoutFileURL, options: .atomic)
                log.debug("[ColumnLayoutStore] layout saved to ~/.mimi/column_layout.json")
            } catch {
                log.error("[ColumnLayoutStore] failed to save layout: \(error.localizedDescription)")
            }
        }

        private nonisolated static func readSnapshot() -> LayoutSnapshot? {
            guard FileManager.default.fileExists(atPath: layoutFileURL.path),
                  let data = try? Data(contentsOf: layoutFileURL),
                  let snapshot = try? JSONDecoder().decode(LayoutSnapshot.self, from: data) else {
                return nil
            }
            return snapshot
        }

        private struct LayoutSnapshot: Codable {
            var left: ColumnLayoutModel
            var right: ColumnLayoutModel
        }

        private(set) var left: ColumnLayoutModel
        private(set) var right: ColumnLayoutModel

        private init() {
            self.left = ColumnLayoutModel(panelSide: .left)
            log.debug("[ColumnLayoutStore] left layout created")
            self.right = ColumnLayoutModel(panelSide: .right)
            log.debug("[ColumnLayoutStore] right layout created")

            loadFromDisk()
            log.info("[ColumnLayoutStore] initialized — layouts loaded once")
        }

        func layout(for side: PanelSide) -> ColumnLayoutModel {
            side == .left ? left : right
        }

        func saveToDisk() {
            let snapshot = LayoutSnapshot(left: left, right: right)
            Task(priority: .utility) {
                Self.writeSnapshot(snapshot)
            }
        }

        private func loadFromDisk() {
            Task(priority: .utility) {
                guard let snapshot = Self.readSnapshot() else { return }
                await MainActor.run {
                    self.left = snapshot.left
                    self.right = snapshot.right
                    log.debug("[ColumnLayoutStore] layout restored from ~/.mimi/column_layout.json")
                }
            }
        }
    }

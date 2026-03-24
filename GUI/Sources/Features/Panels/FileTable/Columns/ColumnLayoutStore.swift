// ColumnLayoutStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton store holding column layouts for both panels.
//              Persisted to ~/.mimi/column_layout.json
//              Migrates from UserDefaults on first run.

import FileModelKit
import SwiftUI

// MARK: - ColumnLayoutStore
@MainActor
@Observable
final class ColumnLayoutStore {
    static let shared = ColumnLayoutStore()

    private static let layoutFileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".mimi", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("column_layout.json")
    }()

    private struct LayoutSnapshot: Codable {
        var left: ColumnLayoutModel
        var right: ColumnLayoutModel
    }

    private(set) var left: ColumnLayoutModel
    private(set) var right: ColumnLayoutModel

    // MARK: - Init
    private init() {
        // Try loading from JSON file first
        if let snapshot = Self.loadFromJSON() {
            self.left = snapshot.left
            self.right = snapshot.right
            log.info("[ColumnLayoutStore] restored from ~/.mimi/column_layout.json")
        }
        // Fallback: try migrating from UserDefaults
        else if let snapshot = Self.migrateFromUserDefaults() {
            self.left = snapshot.left
            self.right = snapshot.right
            log.info("[ColumnLayoutStore] migrated from UserDefaults")
            // Save migrated data to JSON immediately
            saveToDisk()
        }
        // Default: create fresh layouts
        else {
            self.left = ColumnLayoutModel(panelSide: .left)
            self.right = ColumnLayoutModel(panelSide: .right)
            log.debug("[ColumnLayoutStore] created default layouts (no saved config)")
        }
        log.info("[ColumnLayoutStore] init done — left=\(left.columns.count) cols, right=\(right.columns.count) cols")
    }

    func layout(for side: FavPanelSide) -> ColumnLayoutModel {
        side == .left ? left : right
    }

    // MARK: - Save to JSON
    func saveToDisk() {
        let snapshot = LayoutSnapshot(left: left, right: right)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: Self.layoutFileURL, options: .atomic)
            log.debug("[ColumnLayoutStore] saved to ~/.mimi/column_layout.json")
        } catch {
            log.error("[ColumnLayoutStore] save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Load from JSON
    private static func loadFromJSON() -> LayoutSnapshot? {
        guard FileManager.default.fileExists(atPath: layoutFileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: layoutFileURL)
            let snapshot = try JSONDecoder().decode(LayoutSnapshot.self, from: data)
            return snapshot
        } catch {
            log.warning("[ColumnLayoutStore] JSON decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Migrate from UserDefaults (one-time)
    private static func migrateFromUserDefaults() -> LayoutSnapshot? {
        let ud = UserDefaults.standard
        let leftKey = "ColumnLayout.left"
        let rightKey = "ColumnLayout.right"

        guard let leftData = ud.data(forKey: leftKey),
              let rightData = ud.data(forKey: rightKey)
        else {
            return nil
        }

        do {
            let leftCols = try JSONDecoder().decode([ColumnSpec].self, from: leftData)
            let rightCols = try JSONDecoder().decode([ColumnSpec].self, from: rightData)

            // Build ColumnLayoutModel from decoded columns
            let leftModel = ColumnLayoutModel(panelSide: .left)
            leftModel.columns = leftCols

            let rightModel = ColumnLayoutModel(panelSide: .right)
            rightModel.columns = rightCols

            // Remove old UserDefaults keys after successful migration
            ud.removeObject(forKey: leftKey)
            ud.removeObject(forKey: rightKey)
            log.info("[ColumnLayoutStore] removed old UserDefaults keys after migration")

            return LayoutSnapshot(left: leftModel, right: rightModel)
        } catch {
            log.warning("[ColumnLayoutStore] UserDefaults migration failed: \(error.localizedDescription)")
            return nil
        }
    }
}

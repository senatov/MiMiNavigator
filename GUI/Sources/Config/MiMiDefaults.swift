// MiMiDefaults.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: JSON-backed persistent storage replacing UserDefaults.
//   All app preferences, window state, toolbar config, and navigation history
//   are stored as human-readable JSON files under ~/.mimi/
//   Thread-safe: all public API is @MainActor-isolated.
//   Migration: on first run, imports existing UserDefaults values and removes them.

import AppKit
import Foundation

// MARK: - MiMiDefaults
@MainActor
final class MiMiDefaults {
    static let shared = MiMiDefaults()
    private var storage: [String: Any] = [:]
    private let fileURL: URL
    private let dirURL: URL
    private var isDirty = false
    private var coalesceTimer: Timer?

    private enum Constants {
        static let defaultsDirectoryName = ".mimi"
        static let defaultsFileName = "defaults.json"
        static let saveDelay: TimeInterval = 0.5
        static let migrationDoneKey = "MiMiDefaults.migratedFromUserDefaults"
        static let extraMigrationKeys = [
            "MiMi.toolbarOrder",
            "MiMi.toolbarVisible",
            "MiMi.menuBarVisible",
            "MiMi.openWithLRU",
            "MiMi.openWithAppURLs",
            "MiMi.openWithUserAssociations",
            "MiMi.lastPackDestination",
        ]
    }

    // MARK: - Init
    private init() {
        dirURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(Constants.defaultsDirectoryName, isDirectory: true)
        fileURL = dirURL.appendingPathComponent(Constants.defaultsFileName)
        ensureDirectory()
        load()
        migrateFromUserDefaultsIfNeeded()
        subscribeTermination()
    }


    // MARK: - String
    func string(forKey key: String) -> String? {
        guard let value = storage[key] else { return nil }
        guard let string = value as? String else {
            dropInvalidValue(forKey: key, expectedType: "String", actualValue: value)
            return nil
        }
        return string
    }


    // MARK: - Bool / Numbers
    func bool(forKey key: String) -> Bool {
        guard let value = storage[key] else { return false }
        guard let bool = value as? Bool else {
            dropInvalidValue(forKey: key, expectedType: "Bool", actualValue: value)
            return false
        }
        return bool
    }


    func double(forKey key: String) -> Double {
        guard let value = storage[key] else { return 0.0 }
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        dropInvalidValue(forKey: key, expectedType: "Double", actualValue: value)
        return 0.0
    }


    // MARK: - Data / Collections
    func data(forKey key: String) -> Data? {
        guard let value = storage[key] else { return nil }
        guard let base64 = value as? String, let data = Data(base64Encoded: base64) else {
            dropInvalidValue(forKey: key, expectedType: "base64 Data", actualValue: value)
            return nil
        }
        return data
    }


    func array(forKey key: String) -> [Any]? {
        guard let value = storage[key] else { return nil }
        guard let array = value as? [Any] else {
            dropInvalidValue(forKey: key, expectedType: "Array", actualValue: value)
            return nil
        }
        return array
    }


    func stringArray(forKey key: String) -> [String]? {
        guard let value = storage[key] else { return nil }
        guard let array = value as? [String] else {
            dropInvalidValue(forKey: key, expectedType: "[String]", actualValue: value)
            return nil
        }
        return array
    }


    func dictionary(forKey key: String) -> [String: Any]? {
        guard let value = storage[key] else { return nil }
        guard let dictionary = value as? [String: Any] else {
            dropInvalidValue(forKey: key, expectedType: "Dictionary", actualValue: value)
            return nil
        }
        return dictionary
    }


    func object(forKey key: String) -> Any? {
        storage[key]
    }


    // MARK: - URL
    func url(forKey key: String) -> URL? {
        guard let value = storage[key] else { return nil }
        guard let path = value as? String, !path.isEmpty else {
            dropInvalidValue(forKey: key, expectedType: "file URL path", actualValue: value)
            return nil
        }
        return URL(fileURLWithPath: path)
    }


    // MARK: - Setters
    func set(_ value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
        scheduleSave()
    }
    func set(_ value: Bool, forKey key: String) {
        storage[key] = value
        scheduleSave()
    }
    func set(_ value: Double, forKey key: String) {
        storage[key] = value
        scheduleSave()
    }
    func set(_ value: String?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
        scheduleSave()
    }
    func set(_ value: Data?, forKey key: String) {
        if let value {
            storage[key] = value.base64EncodedString()
        } else {
            storage.removeValue(forKey: key)
        }
        scheduleSave()
    }
    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
        scheduleSave()
    }


    // MARK: - Immediate Save
    func synchronize() {
        log.debug("[MiMiDefaults] synchronize requested")
        coalesceTimer?.invalidate()
        coalesceTimer = nil
        saveToDisk()
    }


    // MARK: - Private: Directory
    private func ensureDirectory() {
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            log.debug("[MiMiDefaults] ensureDirectory ok path='\(dirURL.path)'")
        } catch {
            log.error("[MiMiDefaults] ensureDirectory failed: \(error.localizedDescription)")
        }
    }


    // MARK: - Private: Load
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.info("[MiMiDefaults] no defaults.json found — starting fresh")
            return
        }
        do {
            let dict = try SafeJSONStorage.loadJSONObject(from: fileURL, label: "defaults.json")
            storage = dict
            log.info("[MiMiDefaults] loaded \(dict.count) keys from \(fileURL.path)")
        } catch {
            log.error("[MiMiDefaults] load failed: \(error.localizedDescription)")
            SafeJSONStorage.moveUnreadablePrimaryAside(fileURL: fileURL, label: "defaults.json")
            storage = [:]
            isDirty = true
            saveToDisk()
            log.warning("[MiMiDefaults] reset defaults.json to empty defaults after load failure")
        }
    }


    // MARK: - Private: Save
    private func saveToDisk() {
        guard isDirty else { return }
        log.debug("[MiMiDefaults] saveToDisk start keys=\(storage.count)")
        isDirty = false
        do {
            try SafeJSONStorage.writeJSONObject(storage, to: fileURL, label: "defaults.json")
            log.debug("[MiMiDefaults] saved \(storage.count) keys")
        } catch {
            log.error("[MiMiDefaults] save failed: \(error.localizedDescription)")
        }
    }


    // MARK: - Private: Coalesced Save
    private func scheduleSave() {
        isDirty = true
        coalesceTimer?.invalidate()
        coalesceTimer = Timer.scheduledTimer(withTimeInterval: Constants.saveDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveToDisk()
            }
        }
    }


    // MARK: - Private: Migration from UserDefaults
    private func migrateFromUserDefaultsIfNeeded() {
        guard !storage.keys.contains(Constants.migrationDoneKey) else {
            log.debug("[MiMiDefaults] migration already completed")
            return
        }
        let ud = UserDefaults.standard
        var migrated = 0
        for key in PreferenceKeys.allCases {
            let k = key.rawValue
            if let obj = ud.object(forKey: k) {
                if let data = obj as? Data {
                    storage[k] = data.base64EncodedString()
                } else {
                    storage[k] = obj
                }
                ud.removeObject(forKey: k)
                migrated += 1
            }
        }
        for k in Constants.extraMigrationKeys {
            if let obj = ud.object(forKey: k) {
                if let data = obj as? Data {
                    storage[k] = data.base64EncodedString()
                } else {
                    storage[k] = obj
                }
                ud.removeObject(forKey: k)
                migrated += 1
            }
        }
        storage[Constants.migrationDoneKey] = true
        isDirty = true
        if migrated > 0 {
            log.info("[MiMiDefaults] migrated \(migrated) keys from UserDefaults")
            saveToDisk()
        } else {
            log.info("[MiMiDefaults] no UserDefaults keys to migrate")
            saveToDisk()
        }
    }


    // MARK: - Private: Invalid Values
    private func dropInvalidValue(forKey key: String, expectedType: String, actualValue: Any) {
        log.warning("[MiMiDefaults] invalid value for '\(key)': expected \(expectedType), got \(Swift.type(of: actualValue)) — using default")
        storage.removeValue(forKey: key)
        scheduleSave()
    }


    // MARK: - Private: Save on Termination
    private func subscribeTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.synchronize()
                log.info("[MiMiDefaults] saved on app termination")
            }
        }
    }
}

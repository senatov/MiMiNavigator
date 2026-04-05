//
// UserPrefs.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.08.2025.
//

import AppKit
import Foundation

// MARK: - UserPreferences
@MainActor
@Observable
final class UserPreferences {
    static let shared = UserPreferences()
    private let preferencesDirectoryURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
    }()

    private let fileURL: URL

    private var isLoadingSnapshot = false

    // MARK: - Properties
    var snapshot: PreferencesSnapshot = .default {
        didSet {
            guard !isLoadingSnapshot else { return }
            save()
        }
    }

    // MARK: - Initializer
    private init() {
        fileURL = preferencesDirectoryURL.appendingPathComponent("preferences.json")
        log.info(#function)
        subscribeTermination()
    }

    // MARK: - Storage Helpers
    private func ensurePreferencesStorageExists() {
        do {
            try FileManager.default.createDirectory(at: preferencesDirectoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("Failed to create preferences directory: \(error.localizedDescription)")
        }
    }

    private func writeSnapshotToDisk(_ snapshot: PreferencesSnapshot) {
        ensurePreferencesStorageExists()
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            log.info("Preferences saved to ~/.mimi/preferences.json")
        } catch {
            log.error("Failed to save preferences: \(error.localizedDescription)")
        }
    }

    private func writeDefaultSnapshotIfNeeded() {
        ensurePreferencesStorageExists()
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        writeSnapshotToDisk(.default)
        log.info("Created default ~/.mimi/preferences.json")
    }

    // MARK: - Load from preferences.json
    func load() {
        log.info(#function)
        writeDefaultSnapshotIfNeeded()

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PreferencesSnapshot.self, from: data)
            isLoadingSnapshot = true
            snapshot = decoded
            isLoadingSnapshot = false
            log.info("Preferences loaded from ~/.mimi/preferences.json")
        } catch {
            log.error("Failed to load preferences: \(error.localizedDescription)")
            isLoadingSnapshot = true
            snapshot = .default
            isLoadingSnapshot = false
            writeSnapshotToDisk(.default)
        }
    }

    // MARK: - Save to preferences.json
    func save() {
        let snapshotCopy = snapshot
        Task.detached(priority: .utility) { [fileURL] in
            do {
                let directoryURL = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshotCopy)
                try data.write(to: fileURL, options: .atomic)
                log.info("Preferences saved to ~/.mimi/preferences.json")
            } catch {
                log.error("Failed to save preferences: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Apply to AppState
    func apply(to appState: AppState) {
        log.info("Applying preferences (path settings only) to AppState.")
    }

    // MARK: - Capture from AppState
    func capture(from appState: AppState) {
        log.debug(#function + ": leftPath: \(appState.leftPath), rightPath: \(appState.rightPath)")
        var s = snapshot
        s.leftPath = appState.leftPath
        s.rightPath = appState.rightPath
        s.lastSelectedLeftFilePath = appState.selectedLeftFile?.pathStr
        s.lastSelectedRightFilePath = appState.selectedRightFile?.pathStr
        snapshot = s
    }

    // MARK: - Termination Handler
    private func subscribeTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.save()
                log.info("Preferences saved on termination.")
            }
        }
    }
}

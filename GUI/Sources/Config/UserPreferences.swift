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
    private let fileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".mimi", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("preferences.json")
    }()

    // MARK: - Properties
    var snapshot: PreferencesSnapshot = .default

    // MARK: - Initializer
    private init() {
        log.info(#function)
        subscribeTermination()
    }

    // MARK: - Load from preferences.json
    func load() {
        log.info(#function)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.warning("Preferences file not found — using defaults.")
            snapshot = .default
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PreferencesSnapshot.self, from: data)
            snapshot = decoded
            log.info("Preferences loaded from ~/.mimi/preferences.json")
        } catch {
            log.error("Failed to load preferences: \(error.localizedDescription)")
            snapshot = .default
        }
    }

    // MARK: - Save to preferences.json
    func save() {
        let snapshotCopy = snapshot
        let targetURL = fileURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshotCopy)
                try data.write(to: targetURL, options: .atomic)
                log.info("Preferences saved to ~/.mimi/preferences.json")
            } catch {
                log.error("Failed to save preferences: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Apply to AppState
    func apply(to appState: AppState) {
        log.info("Applying preferences (non-path settings) to AppState.")
    }

    // MARK: - Capture from AppState
    func capture(from appState: AppState) {
        log.debug(#function + ": leftPath: \(appState.leftPath), rightPath: \(appState.rightPath)")
        // Build updated snapshot in one assignment to avoid triggering didSet multiple times
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

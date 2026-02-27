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
    private let defaults = UserDefaults.standard

    // MARK: - Properties
    var snapshot: PreferencesSnapshot = .default {
        didSet { save() }
    }

    // MARK: - Initializer
    private init() {
        log.info(#function)
        subscribeTermination()
    }

    // MARK: - Load from UserDefaults
    func load() {
        log.info(#function)
        var s = PreferencesSnapshot.default
        if let value = defaults.string(forKey: PreferenceKeys.leftPath.rawValue),
            !value.isEmpty
        {
            s.leftPath = value
        } else {
            log.warning("Missing leftPath — using default.")
        }
        if let value = defaults.string(forKey: PreferenceKeys.rightPath.rawValue),
            !value.isEmpty
        {
            s.rightPath = value
        } else {
            log.warning("Missing rightPath — using default.")
        }
        if defaults.object(forKey: PreferenceKeys.showHiddenFiles.rawValue) != nil {
            s.showHiddenFiles = defaults.bool(forKey: PreferenceKeys.showHiddenFiles.rawValue)
        } else {
            log.warning("Missing showHiddenFiles — using default.")
        }
        if defaults.object(forKey: PreferenceKeys.favoritesMaxDepth.rawValue) != nil {
            let val = defaults.integer(forKey: PreferenceKeys.favoritesMaxDepth.rawValue)
            s.favoritesMaxDepth = max(val, 0)
        } else {
            log.warning("Missing favoritesMaxDepth — using default.")
        }
        if let arr = defaults.array(forKey: PreferenceKeys.expandedFolders.rawValue) as? [String] {
            s.expandedFolders = Set(arr)
        } else {
            log.warning("Missing expandedFolders — using default.")
        }
        s.lastSelectedLeftFilePath = defaults.string(forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue)
        s.lastSelectedRightFilePath = defaults.string(forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue)

        snapshot = s
        log.info("Preferences loaded.")
    }

    // MARK: - Save to UserDefaults
    func save() {
        log.info(#function)
        defaults.set(snapshot.leftPath, forKey: PreferenceKeys.leftPath.rawValue)
        defaults.set(snapshot.rightPath, forKey: PreferenceKeys.rightPath.rawValue)
        defaults.set(snapshot.showHiddenFiles, forKey: PreferenceKeys.showHiddenFiles.rawValue)
        defaults.set(snapshot.favoritesMaxDepth, forKey: PreferenceKeys.favoritesMaxDepth.rawValue)
        defaults.set(Array(snapshot.expandedFolders), forKey: PreferenceKeys.expandedFolders.rawValue)
        defaults.set(snapshot.lastSelectedLeftFilePath, forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue)
        defaults.set(snapshot.lastSelectedRightFilePath, forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue)

        log.info("Preferences saved.")
    }

    // MARK: - Apply to AppState
    func apply(to appState: AppState) {
        log.info("Applying preferences to AppState.")
        appState.leftPath = snapshot.leftPath
        appState.rightPath = snapshot.rightPath
    }

    // MARK: - Capture from AppState
    func capture(from appState: AppState) {
        log.info("Capturing AppState into preferences.")
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

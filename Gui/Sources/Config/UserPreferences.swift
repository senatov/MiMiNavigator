//
//  UserPreferences.swift
//  MiMiNavigator
//
//  Created by ChatGPT on 10.08.2025.
//

import AppKit
import Combine
import Foundation


struct PreferencesSnapshot: Codable, Sendable {
    var leftPath: String
    var rightPath: String
    var showHiddenFiles: Bool
    var favoritesMaxDepth: Int
    var expandedFolders: Set<String>
    var lastSelectedLeftFilePath: String?
    var lastSelectedRightFilePath: String?

    static let `default` = PreferencesSnapshot(
        leftPath: FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first?.path ?? "/",
        rightPath: FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.path ?? "/",
        showHiddenFiles: false,
        favoritesMaxDepth: 2,
        expandedFolders: [],
        lastSelectedLeftFilePath: nil,
        lastSelectedRightFilePath: nil
    )
}

// MARK: - PrefKey

private enum PrefKey: String, CaseIterable {
    case leftPath
    case rightPath
    case showHiddenFiles
    case favoritesMaxDepth
    case expandedFolders
    case lastSelectedLeftFilePath
    case lastSelectedRightFilePath
}

// MARK: - UserPreferences

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    private let defaults = UserDefaults.standard

    // MARK: -
    @Published
    var snapshot: PreferencesSnapshot = .default {
        didSet { save() }
    }

    // MARK: -
    private init() {
        log.info("UserPreferences initialized.")
        subscribeTermination()
    }

    // MARK: -
    func load() {
        log.info("Loading preferences…")
        var s = PreferencesSnapshot.default

        if let value = defaults.string(forKey: PrefKey.leftPath.rawValue),
           !value.isEmpty
        {
            s.leftPath = value
        } else {
            log.warning("Missing leftPath — using default.")
        }

        if let value = defaults.string(forKey: PrefKey.rightPath.rawValue),
           !value.isEmpty
        {
            s.rightPath = value
        } else {
            log.warning("Missing rightPath — using default.")
        }

        if defaults.object(forKey: PrefKey.showHiddenFiles.rawValue) != nil {
            s.showHiddenFiles = defaults.bool(forKey: PrefKey.showHiddenFiles.rawValue)
        } else {
            log.warning("Missing showHiddenFiles — using default.")
        }

        if defaults.object(forKey: PrefKey.favoritesMaxDepth.rawValue) != nil {
            let val = defaults.integer(forKey: PrefKey.favoritesMaxDepth.rawValue)
            s.favoritesMaxDepth = max(val, 0)
        } else {
            log.warning("Missing favoritesMaxDepth — using default.")
        }

        if let arr = defaults.array(forKey: PrefKey.expandedFolders.rawValue) as? [String] {
            s.expandedFolders = Set(arr)
        } else {
            log.warning("Missing expandedFolders — using default.")
        }

        s.lastSelectedLeftFilePath = defaults.string(forKey: PrefKey.lastSelectedLeftFilePath.rawValue)
        s.lastSelectedRightFilePath = defaults.string(forKey: PrefKey.lastSelectedRightFilePath.rawValue)

        snapshot = s
        log.info("Preferences loaded.")
    }

    // MARK: -
    func save() {
        defaults.set(snapshot.leftPath, forKey: PrefKey.leftPath.rawValue)
        defaults.set(snapshot.rightPath, forKey: PrefKey.rightPath.rawValue)
        defaults.set(snapshot.showHiddenFiles, forKey: PrefKey.showHiddenFiles.rawValue)
        defaults.set(snapshot.favoritesMaxDepth, forKey: PrefKey.favoritesMaxDepth.rawValue)
        defaults.set(Array(snapshot.expandedFolders), forKey: PrefKey.expandedFolders.rawValue)
        defaults.set(snapshot.lastSelectedLeftFilePath, forKey: PrefKey.lastSelectedLeftFilePath.rawValue)
        defaults.set(snapshot.lastSelectedRightFilePath, forKey: PrefKey.lastSelectedRightFilePath.rawValue)

        log.info("Preferences saved.")
    }

    // MARK: -
    func apply(to appState: AppState) {
        log.info("Applying preferences to AppState.")
        appState.leftPath = snapshot.leftPath
        appState.rightPath = snapshot.rightPath
    }

    // MARK: -
    func capture(from appState: AppState) {
        log.info("Capturing AppState into preferences.")
        snapshot.leftPath = appState.leftPath
        snapshot.rightPath = appState.rightPath
        snapshot.lastSelectedLeftFilePath = appState.selectedLeftFile?.pathStr
        snapshot.lastSelectedRightFilePath = appState.selectedRightFile?.pathStr
    }

    // MARK: -
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

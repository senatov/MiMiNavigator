//
//  DirectoryEventManager.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.01.25.
//  Description: Intermediate logic layer that intercepts raw monitoring events
//  and augments them with business logic, filtering, buffering, etc.
//

import Foundation

/// Handles directory-related events and processes them for higher-level logic.
final class DirectoryEventManager {
    // Stores additional state, e.g., last modification time or a change counter
    private var lastKnownState: String = "OK"

    // Callback for the client to notify about a new event
    var onStateUpdated: ((String) -> Void)?

    /// Default initializer
    init() {}

    // MARK: - Handles a directory change event triggered by `DirectoryMonitor`
    func handleDirectoryChangeEvent() {
        // Complex logic can go here:
        // - Check the actual directory content
        // - Filter files based on criteria
        // - Apply delays or batching

        // For now, just update the state string
        lastKnownState = "Directory has changed!"
        onStateUpdated?(lastKnownState)
    }
}

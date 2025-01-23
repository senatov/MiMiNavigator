//
//  DirectoryMonitor.swift
//  Directory Monitoring Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Copyright © 2025 Senatov. All rights reserved.

//  Description: This file contains the implementation of the `DirectoryMonitor` class,
//  which is responsible for monitoring a directory for changes in its modification date.
//  The class uses `Swift Concurrency` and ensures safe access to MainActor-isolated properties.
//
//  Dependencies: Foundation, Combine
//

//
//  DirectoryMonitor.swift
//  Directory Monitoring Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Description: This file contains the implementation of the `DirectoryMonitor` class,
//  which is responsible for monitoring a directory for changes in its modification date.
//  The class uses `Swift Concurrency` and ensures safe access to MainActor-isolated properties.
//
//  Dependencies: Foundation, Combine
//

    //
    //  DirectoryMonitor.swift
    //  Directory Monitoring Utility
    //
    //  Created by Iakov Senatov on 23.01.25.
    //  Description: Monitors a directory for changes in its modification date using Swift Concurrency.
    //
    //  Dependencies: Foundation, Combine
    //

import Combine
import Foundation

    /// A class for monitoring a directory for changes to its modification date.
    /// Thread-safe and isolated with `@MainActor`.
@MainActor
final class DirectoryMonitor: ObservableObject, Sendable {

        // Timer for periodic directory checks
    private var timer: Timer? = nil

        // URL of the monitored directory
    private let directoryURL: URL

        // Published property to hold the last modification date (isolated to MainActor)
    @Published private var lastModificationDate: Date? = nil

        // Callback for directory changes
    var onDirectoryChanged: (@Sendable () -> Void)? = nil

        /// Initializes the DirectoryMonitor with a directory path.
        /// - Parameter directoryPath: Path to the directory to monitor.
    init(directoryPath: String) {
        self.directoryURL = URL(fileURLWithPath: directoryPath)
        startMonitoring()
    }

        /// Deinitializer for ensuring cleanup of resources.
    deinit {
            // Use a safe detached cleanup process for the timer
        invalidateTimerNonisolated()
    }

        /// Starts monitoring the directory for changes.
    func startMonitoring() {
            // Ensure the timer is invalidated before creating a new one
        cleanupTimer()

            // Create a timer on the main thread to periodically check for directory changes
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.checkDirectoryChanges()
            }
        }
    }

        /// Stops monitoring the directory by invalidating the timer.
    func stopMonitoring() {
        cleanupTimer()
    }

        /// Private helper to clean up the timer safely.
    private func cleanupTimer() {
            // Timer cleanup should only happen in the MainActor context
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }

        /// Nonisolated helper for invalidating the timer in `deinit`.
    private nonisolated func invalidateTimerNonisolated() {
            // Safely transfer cleanup responsibility to MainActor
        Task { @MainActor in
            if let timer = self.timer {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

        /// Checks if the directory's modification date has changed.
    private func checkDirectoryChanges() async {
        do {
                // Fetch directory attributes in a background thread
            let attributes = try await fetchDirectoryAttributes()

                // Extract the modification date
            guard let modificationDate = attributes[.modificationDate] as? Date else { return }

                // Notify if the modification date has changed
            if let lastDate = lastModificationDate, lastDate != modificationDate {
                onDirectoryChanged?()
            }

                // Update the last known modification date
            lastModificationDate = modificationDate
        } catch {
                // Log the error
            print("Directory check error: \(error.localizedDescription)")
        }
    }

        /// Fetches directory attributes using a background queue.
        /// - Returns: A dictionary of file attributes.
    private func fetchDirectoryAttributes() async throws -> [FileAttributeKey: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                        // Get attributes of the directory
                    let attributes = try FileManager.default.attributesOfItem(atPath: self.directoryURL.path)
                    continuation.resume(returning: attributes) // Return the attributes
                } catch {
                    continuation.resume(throwing: error) // Return the error
                }
            }
        }
    }
}

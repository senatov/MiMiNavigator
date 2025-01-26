//
//  DirectoryMonitor.swift
//  Directory Monitoring Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Description: A basic implementation of a class for monitoring directory modification dates.
//  No async/await, @MainActor, or actor used.
//
//  Dependencies: Foundation, Combine
//

import Combine
import Foundation

/// Not marked as an actor or @MainActor to avoid isolation issues.
final class DirectoryMonitor: ObservableObject {
    // Timer for periodically checking the directory
    private var timer: Timer?
    // Path to the monitored directory
    private let directoryURL: URL
    // Stores the last known modification date
    @Published private var lastModificationDate: Date?
    // Callback triggered when the directory changes
    var onDirectoryChanged: (() -> Void)?

    /// Initializer takes a directory path as a string.
    /// Starts monitoring immediately after initialization.
    init(directoryPath: String) {
        self.directoryURL = URL(fileURLWithPath: directoryPath)
        startMonitoring()
    }

    /// Stops the timer when the object is deallocated.
    deinit {
        stopMonitoring()
    }

    // MARK: - Starts monitoring the directory, checks every 5 seconds.
    func startMonitoring() {
        log.info("startMonitoring()")
        stopMonitoring()  // Kill any previous timer if it exists
        // Old-school timer creation
        let newTimer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkDirectoryChanges()
        }
        // Save the timer reference
        timer = newTimer
        // Add the timer to the current run loop (usually .commonModes)
        RunLoop.main.add(newTimer, forMode: .common)
    }

    // MARK: - Stops monitoring (invalidates the timer if running).
    func stopMonitoring() {
        log.info("stopMonitoring()")
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Checks if the directory's modification date has changed.
    private func checkDirectoryChanges() {
        log.info("checkDirectoryChanges()")
        do {
            // Get file attributes (sync call)
            let attributes = try FileManager.default.attributesOfItem(atPath: directoryURL.path)
            // Extract the modification date
            guard let modificationDate = attributes[.modificationDate] as? Date else { return }
            // Trigger the callback if the new date is different
            if let lastDate = lastModificationDate, lastDate != modificationDate {
                onDirectoryChanged?()
            }
            // Update the date for the next check
            lastModificationDate = modificationDate
        } catch {
            print("Error while checking the directory: \(error.localizedDescription)")
        }
    }
}

// Adding @unchecked Sendable to suppress thread-safety warnings
extension DirectoryMonitor: @unchecked Sendable {}

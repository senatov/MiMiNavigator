//
//  DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.11.24.
//  Description: Actor-based utility for monitoring and synchronizing file updates in two directories.
//  Dependencies: Foundation, Combine, SwiftUI
//

import Combine
import Foundation
import SwiftUI

/// Stores and tracks changes in two directories, ensuring thread safety through actor isolation.
actor DualDirectoryScanner: ObservableObject {
    /// Update interval (in seconds).
    private let interval = 15

    /// Files from the left directory.
    @Published private(set) var leftFiles: [CustomFile] = []
    /// Files from the right directory.
    @Published private(set) var rightFiles: [CustomFile] = []

    /// Timers for directory updates.
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?

    /// URL addresses of the left and right directories.
    private(set) var leftDirectory: URL
    private(set) var rightDirectory: URL

    // MARK: - DirectorySide: left or right
    private enum DirectorySide: CustomStringConvertible {
        case left, right
        var description: String {
            switch self {
            case .left:
                return "left"
            case .right:
                return "right"
            }
        }
    }

    // MARK: - Initialization
    init(leftDirectory: URL, rightDirectory: URL) {
        log.info("DualDirectoryScanner: init()")
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
        log.info("Monitoring started. beginn")
        Task { [weak self] in
            await self?.startMonitoring()
        }
        log.info("Monitoring started. ok")
    }

    // MARK: - Start monitoring both directories
    func startMonitoring() {
        log.info("startMonitoring()")
        setupTimer(for: .left)
        setupTimer(for: .right)
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: - Private methods
    private func setupTimer(for side: DirectorySide) {
        log.info("setupTimer() \(side)")
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(interval))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshFiles(for: side)
            }
        }
        timer.resume()
        switch side {
        case .left:
            leftTimer = timer
        case .right:
            rightTimer = timer
        }
        log.info("End setupTimer() \(side)")
    }

    // MARK: - Stop monitoring (cancel timers)
    func stopMonitoring() {
        log.info("stopMonitoring()")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    private func refreshFiles(for side: DirectorySide) async {
        log.debug("refreshFiles() for <<\(side)>> directory.")
        let directoryURL = (side == .left) ? leftDirectory : rightDirectory
        do {
            let files = try await scanDirectory(at: directoryURL)
            switch side {
            case .left:
                leftFiles = files
                log.info("Left directory updated with \(files.count) files.")
            case .right:
                rightFiles = files
                log.info("Right directory updated with \(files.count) files.")
            }
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
        }
    }

    private func scanDirectory(at url: URL) async throws -> [CustomFile] {
        let fileManager = FileManager.default
        var customFiles: [CustomFile] = [
            CustomFile(
                name: "...",
                path: "..",
                isDirectory: true,
                children: []
            )
        ]
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for fileURL in contents {
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let customFile = CustomFile(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDirectory,
                children: []
            )
            customFiles.append(customFile)
        }
        return customFiles
    }

    // MARK: - Getting a snapshot of files for the UI
    func snapshotLeftFiles() -> [CustomFile] {
        return leftFiles
    }

    func snapshotRightFiles() -> [CustomFile] {
        return rightFiles
    }

    // MARK: - Switching directories
    func setLeftDirectory(url: URL) {
        self.leftDirectory = url
    }
    func setRightDirectory(url: URL) {
        self.rightDirectory = url
    }
}

//
//  DualDirScanner.swift
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
actor DualDirScanner: ObservableObject {
    /// Update interval (in seconds).
    private let interval = 15

    /// Files from the left dir.
    @Published private(set) var leftFiles: [CustomFile] = []
    /// Files from the right dir.
    @Published private(set) var rightFiles: [CustomFile] = []

    /// Timers for dir updates.
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?

    /// URL addresses of the left and right directories.
    private(set) var leftDir: URL
    private(set) var rightDir: URL

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
        self.leftDir = leftDirectory
        self.rightDir = rightDirectory
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

    // MARK: -
    private func refreshFiles(for side: DirectorySide) async {
        log.debug("refreshFiles() for <<\(side)>> directory.")
        let directoryURL = (side == .left) ? leftDir : rightDir
        do {
            let files = try await scanDirectory(at: directoryURL)

            switch side {
            case .left:
                self.leftFiles = files
                log.info("Left dir updated with \(files.count) files.")
            case .right:
                self.rightFiles = files
                log.info("Right dir updated with \(files.count) files.")
            }
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
        }
    }

    // MARK: -
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

    // MARK: -
    func snapshotRightFiles() -> [CustomFile] {
        return rightFiles
    }

    // MARK: - Switching directories
    func setLeftDirectory(url: URL) {
        self.leftDir = url
    }
    func setRightDirectory(url: URL) {
        self.rightDir = url
    }
}

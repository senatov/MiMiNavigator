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

/// Manages dual directory monitoring with periodic file refreshes.
actor DualDirectoryScanner: ObservableObject {
    let interval = 15
    // Singleton for shared file management logic
    var fileLst = FileSingleton.shared
    // Timers for both directories
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    // Directory paths
    public var leftDirectory: URL
    public var rightDirectory: URL

    private enum DirectorySide {
        case left, right
    }

    // MARK: - Initialization
    init(leftDirectory: URL, rightDirectory: URL) {
        log.info("init()")
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
        log.debug("\n --- DualDirectoryScanner initialized.----")
        Task { @MainActor in
            await self.startMonitoring()
        }
    }

    // MARK: - Starts timers for both directories with custom refresh intervals
    func startMonitoring() {
        log.info("startMonitoring()")
        setupTimer(for: .left)
        setupTimer(for: .right)

        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: - Helper method to setup timers
    private func setupTimer(for side: DirectorySide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(interval))
        timer.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(for: side)
            }
        }
        timer.resume()
        switch side {
        case .left:
            leftTimer = timer
        case .right:
            rightTimer = timer
        }
    }

    // MARK: - Stops monitoring by canceling timers
    func stopMonitoring() {
        log.info("stopMonitoring()")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // MARK: - Refreshes the file list for a specific directory side
    private func refreshFiles(for side: DirectorySide) async {
        log.debug("refreshFiles() for <<\(side)>> directory.")
        let directoryURL: URL
        switch side {
        case .left:
            directoryURL = leftDirectory
        case .right:
            directoryURL = rightDirectory
        }
        let files: [CustomFile]
        do {
            files = try await scanDirectory(at: directoryURL)
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
            files = []
        }
        await updateFileList(for: side, with: files)
    }

    // MARK: - Updates the file list for the specified directory side
    private func updateFileList(for side: DirectorySide, with files: [CustomFile]) async {
        log.info("updateFileList()")
        switch side {
        case .left:
            await fileLst.updateLeftFiles(files)
            log.info("Left directory updated with \(files.count) files.")
        case .right:
            await fileLst.updateRightFiles(files)
            log.info("Right directory updated with \(files.count) files.")
        }
    }

    // MARK: - Scans a directory for files and directories
    private func scanDirectory(at url: URL?) async throws -> [CustomFile] {
        log.info("scanDirectory() dir: \(String(describing: url?.path))")
        guard let url = url else {
            log.error("Invalid directory URL: URL is nil.")
            return []
        }
        let fileManager = FileManager.default
        var customFiles: [CustomFile] = []
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            )
            for fileURL in contents {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let customFile = CustomFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    isDirectory: isDirectory
                )
                customFiles.append(customFile)
            }
        } catch {
            log.error("Failed to scan directory at: \(url.path): \(error.localizedDescription)")
            throw error
        }
        return customFiles
    }

    // MARK: - Updates the left directory's path
    func setLeftDirectory(path: String) {
        Task {
            self.leftDirectory = URL(fileURLWithPath: path)
        }
    }

    // MARK: - Updates the right directory's path
    func setRightDirectory(path: String) {
        Task {
            self.rightDirectory = URL(fileURLWithPath: path)
        }
    }
}

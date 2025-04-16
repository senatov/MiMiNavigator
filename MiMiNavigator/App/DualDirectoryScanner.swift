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

// MARK: - Manages dual directory monitoring with periodic file refreshes.
actor DualDirectoryScanner: ObservableObject {
    let interval = 15

    // Singleton for shared file management logic
    var fileLst = FileSingleton.shared
    // Timers for both directories
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    // Directory paths
    var leftDirectory: URL
    var rightDirectory: URL

    // MARK: -
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
        log.info("init()")
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
        log.debug("\n --- DualDirectoryScanner initialized.----")
        Task(priority: .low) { @MainActor in
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
        log.info("setupTimer() \(side)")
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
        let rootCustomFile = CustomFile(
            name: "...",
            path: "..",
            isDirectory: true
        )
        let fileManager = FileManager.default
        var customFiles: [CustomFile] = [rootCustomFile]
        do {
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
                    isDirectory: isDirectory
                )
                customFiles.append(customFile)
            }
        } catch {
            log.error("Failed to scan directory at: \(url.path): \(error.localizedDescription)")
            throw error
        }
        log.debug("Scanned files: \(customFiles)")
        return customFiles
    }

    // MARK: -
    func setLeftDirectory(path: String) {
        self.leftDirectory = URL(fileURLWithPath: path)
    }

    // MARK: -
    func setRightDirectory(path: String) {
        self.rightDirectory = URL(fileURLWithPath: path)
    }

}

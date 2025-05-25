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
    let interval = 45
    var fileLst = FileSingleton.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    var leftDirectory: URL = URL.documentsDirectory
    var rightDirectory: URL = URL.downloadsDirectory

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

    // - MAR Initialization
    init(leftDirectory: SelectedDir, rightDirectory: SelectedDir) {
        log.debug(#function)
        if let url = leftDirectory.selectedFSEntity?.url {
            self.leftDirectory = url
        } else {
            log.error("leftDirectory.selectedFSEntity is nil — assigning home directory.")
            self.leftDirectory = URL.homeDirectory
        }
        if let url = rightDirectory.selectedFSEntity?.url {
            self.rightDirectory = url
        } else {
            log.error("rightDirectory.selectedFSEntity is nil — assigning home directory.")
            self.rightDirectory = URL.homeDirectory
        }
        Task(priority: .low) { @MainActor in
            await self.startMonitoring()
        }
    }

    // MARK: - Starts timers for both directories with custom refresh intervals
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: .left)
        setupTimer(for: .right)
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: - Helper method to setup timers
    private func setupTimer(for side: DirectorySide) {
        log.info(#function)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(interval))
        timer.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(side: side)
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
    private func refreshFiles(side: DirectorySide) async {
        log.info(#function)
        let files: [CustomFile]
        let directoryURL: URL
        switch side {
        case .left:
            directoryURL = leftDirectory
        case .right:
            directoryURL = rightDirectory
        }
        do {
            files = try await scanDirectory(url: directoryURL)
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
            files = []
        }
        await updateFileList(side: side, with: files)
    }

    // MARK: - Scans a directory for files and directories
    private func scanDirectory(url: URL?) async throws -> [CustomFile] {
        log.info("scanDirectory() dir: \(String(describing: url?.relativePath)))")
        guard let url = url else {
            log.error("Invalid directory URL: URL is nil.")
            return []
        }
        let rootCustomFile = CustomFile(
            name: "...",
            path: "..",
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
                let customFile = CustomFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                )
                customFiles.append(customFile)
            }
        } catch {
            log.error("Failed to scan directory at: \(url.path): \(error.localizedDescription)")
            throw error
        }
        log.debug("Scanned files nummer: \(customFiles.count)")
        return customFiles
    }

    // MARK: - Updates the file list for the specified directory side
    private func updateFileList(side: DirectorySide, with files: [CustomFile]) async {
        switch side {
        case .left:
            log.debug("Updating left directory with \(files.count) files.")
            await fileLst.updateLeftFiles(files)
            log.debug("Finished updating left directory.")
        case .right:
            log.debug("Updating right directory with \(files.count) files.")
            await fileLst.updateRightFiles(files)
            log.debug("Finished updating right directory.")
        }
    }

    // MARK: -
    func setLeftDirectory(pathStr: String) {
        self.leftDirectory = URL(fileURLWithPath: pathStr)
    }

    // MARK: -
    func setRightDirectory(pathStr: String) {
        self.rightDirectory = URL(fileURLWithPath: pathStr)
    }

}

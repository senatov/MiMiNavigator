//  DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.11.24.
//

import Combine
import Foundation
import SwiftUI

actor DualDirectoryScanner: ObservableObject {
    var fileLst = FileSingleton.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    public var leftDirectory: URL
    public var rightDirectory: URL

    private enum DirectorySide {
        case left, right
    }

    // MARK: -

    init(leftDirectory: URL, rightDirectory: URL) {
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory

        log.debug("DualDirectoryScanner initialized.")
        log.debug("left directory: \(leftDirectory.path)")
        log.debug("right directory: \(rightDirectory.path)")

        // Start monitoring in an asynchronous task after initialization
        Task { [weak self] in
            await self?.startMonitoring()
        }
    }

    private func initializeMonitoring() {
        // Start monitoring in an asynchronous task to handle actor isolation
        Task {
            startMonitoring()
        }
    }

    // MARK: - Starts monitoring both directories with a 1-second refresh interval.

    func startMonitoring() {
        log.info("Starting monitoring both directories.")
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: .seconds(5))
        leftTimer?.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(for: .left)
            }
        }
        leftTimer?.resume()

        // Setup right directory timer
        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: .seconds(5))
        rightTimer?.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(for: .right)
            }
        }
        rightTimer?.resume()

        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: - Stops monitoring both directories and cancels active timers.

    func stopMonitoring() {
        log.info("Stop monitoring both directories.")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // MARK: - Refreshes file list for the specified directory side.

    private func refreshFiles(for side: DirectorySide) async {
        log.debug("Refreshing files for \(side) directory.")

        // Определяем URL директории
        let directoryURL: URL
        switch side {
        case .left:
            directoryURL = leftDirectory
        case .right:
            directoryURL = rightDirectory
        }

        // Асинхронное сканирование директории
        let files: [CustomFile]
        do {
            files = try await scanDirectory(at: directoryURL)
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
            files = []
        }

        // Обновление файла и логирование
        await updateFileList(for: side, with: files)
    }

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

    // MARK: - Scans the specified directory URL for files and directories.

    private func scanDirectory(at url: URL?) async throws -> [CustomFile] {
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
            log.error("Failed to scan directory at \(url.path): \(error.localizedDescription)")
            throw error
        }
        return customFiles
    }

    func setLeftDirectory(path: String) {
        Task {
            self.leftDirectory = URL(fileURLWithPath: path)
        }
    }

    func setRightDirectory(path: String) {
        Task {
            self.rightDirectory = URL(fileURLWithPath: path)
        }
    }
}

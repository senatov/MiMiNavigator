//
//  DualDirectoryMonitor.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.

//  Description:

import Foundation
import SwiftyBeaver

actor DualDirectoryMonitor: ObservableObject {
    // Initialize logger
    let log = SwiftyBeaver.self

    private(set) var leftFiles: [CustomFile] = []
    private(set) var rightFiles: [CustomFile] = []

    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL

    init(leftDirectory: URL, rightDirectory: URL) {
        log.debug("init()")
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
    }

    func startMonitoring() {
        log.debug("Starting directory monitoring.")
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        leftTimer?.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.refreshFiles(for: .left)
            }
        }
        leftTimer?.resume()
        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        rightTimer?.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.refreshFiles(for: .right)
            }
        }
        rightTimer?.resume()
    }

    func stopMonitoring() {
        log.debug("Stopping directory monitoring.")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    func getLeftFiles() -> [CustomFile] {
        return leftFiles
    }

    func getRightFiles() -> [CustomFile] {
        return rightFiles
    }

    private enum DirectorySide {
        case left, right
    }

    private func refreshFiles(for side: DirectorySide) async {
        log.debug("refreshFiles()")
        let directoryURL = side == .left ? leftDirectory : rightDirectory
        let files = fetchFiles(in: directoryURL)

        switch side {
        case .left:
            leftFiles = files
        case .right:
            rightFiles = files
        }
    }

    private func fetchFiles(in directory: URL) -> [CustomFile] {
        var files: [CustomFile] = []
        log.debug("fetchFiles()")
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isReadableKey, .isDirectoryKey], options: [.skipsHiddenFiles])

            for url in fileURLs {
                let resourceValues = try url.resourceValues(forKeys: [.isReadableKey, .isDirectoryKey])
                guard resourceValues.isReadable == true else {
                    log.debug("Skipping unreadable file: \(url.lastPathComponent)")
                    continue
                }

                let isDirectory = resourceValues.isDirectory ?? false
                let file = CustomFile(
                    name: url.lastPathComponent,
                    path: url.path,
                    isDirectory: isDirectory,
                    children: isDirectory ? fetchFiles(in: url) : nil
                )
                files.append(file)
            }
        } catch {
            log.error("Error reading contents of directory: \(error.localizedDescription)")
        }

        return files
    }
}

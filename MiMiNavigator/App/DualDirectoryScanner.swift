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
    var fileLst = FileSingleton.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    
    @Published var leftDirectory: URL = URL.documentsDirectory
    @Published var rightDirectory: URL = URL.downloadsDirectory
    @Published var selectedDirectory: URL = URL.documentsDirectory
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []
    
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
        Task(priority: .low) { @MainActor in
            await self.startMonitoring()
        }
    }
        // MARK: -
    public func setRightDirectory(pathStr: String) async {
        self.rightDirectory = URL(fileURLWithPath: pathStr)
    }
        // MARK: -
    public func setLeftDirectory(pathStr: String) async {
        self.leftDirectory = URL(fileURLWithPath: pathStr)
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
            log.info("Timer triggered for side: \(side)")
            guard let self = self else {
                log.warning("DualDirectoryScanner deallocated before timer fired for side: \(side)")
                return
            }
            Task { @MainActor in
                log.info("Starting file refresh task for side: \(side)")
                await self.refreshFiles(side: side)
                log.info("Completed file refresh task for side: \(side)")
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
        do {
            switch side {
                case .left:
                    let scanned = try FileScanner.scan(url: leftDirectory)
                    self.updateScannedFiles(scanned, for: .left)
                    await updateFileList(side: side, with: scanned)
                case .right:
                    let scanned = try FileScanner.scan(url: rightDirectory)
                    self.updateScannedFiles(scanned, for: .right)
                    await updateFileList(side: side, with: scanned)
            }
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
        }
    }
    
    private func updateScannedFiles(_ files: [CustomFile], for side: DirectorySide) {
        switch side {
            case .left:
                self.leftFiles = files
            case .right:
                self.rightFiles = files
        }
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
    
}

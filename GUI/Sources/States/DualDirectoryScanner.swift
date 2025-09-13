//
//  DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//  Description: Actor-based utility for monitoring and synchronizing file updates in two directories.
//  Dependencies: Foundation, Combine, SwiftUI
//
import Combine
import Foundation
import SwiftUI

// MARK: - Manages dual directory monitoring with periodic file refreshes.
actor DualDirectoryScanner {
    let appState: AppState
    var fileLst = FileSingleton.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let timeOutRefresh: Int = 300

    // MARK: -
    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Starts timers for both directories with custom refresh intervals
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: .right)
        setupTimer(for: .left)
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: -
    func setRightDirectory(pathStr: String) {
        log.info("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
    }

    // MARK: -
    func setLeftDirectory(pathStr: String) {
        log.info("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
    }

    // MARK: - Helper method to setup timers
    private func setupTimer(for currSide: PanelSide) {
        log.info(#function)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(timeOutRefresh))
        timer.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }
            Task { @MainActor in
                await self.refreshFiles(currSide: currSide)
            }
        }
        timer.resume()
        switch currSide {
        case .left: leftTimer = timer
        case .right: rightTimer = timer
        }
    }

    // MARK: - Refreshes the file list for a specific directory side
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        log.info(#function + " currSide: \(currSide)")
        do {
            switch currSide {
            case .left:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.leftPath))
                await updateScannedFiles(scanned, for: .left)
                await updateFileList(currSide: .left, with: scanned)

            case .right:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.rightPath))
                await updateScannedFiles(scanned, for: .right)
                await updateFileList(currSide: .right, with: scanned)
            }
        }
        catch {
            log.error("Failed to scan \(currSide) directory: \(error.localizedDescription)")
        }
    }

    // MARK: -
    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for currSide: PanelSide) {
        log.info(#function + " currSide: \(currSide)")
        log.info("Updating AppState.\(currSide)Panel with \(files.count) files.")
        let sorted = appState.applySorting(files)
        switch currSide {
        case .left:
            appState.displayedLeftFiles = sorted
        case .right:
            appState.displayedRightFiles = sorted
        }
    }

    // MARK: -
    func resetRefreshTimer(for currSide: PanelSide) {
        log.info("↪️ \(#function) [currSide: \(currSide)]")
        switch currSide {
        case .left:
            leftTimer?.cancel()
            leftTimer = nil
            setupTimer(for: .left)

        case .right:
            rightTimer?.cancel()
            rightTimer = nil
            setupTimer(for: .right)
        }
    }

    @MainActor
    // MARK: - Updates the file list for the specified directory side
    private func updateFileList(currSide: PanelSide, with files: [CustomFile]) async {
        log.info("↪️ \(#function) [currSide: \(currSide)]")
        guard let selectedEntity = appState.selectedDir.selectedFSEntity else {
            log.warning("No selected FSEntity for \(currSide) side.")
            return
        }
        log.info("Updating selected dir: \(selectedEntity.pathStr) with \(files.count) files on \(currSide) side")
        switch currSide {
        case .left:
            await fileLst.updateLeftFiles(files)
        case .right:
            await fileLst.updateRightFiles(files)
        }
        log.info("Finished updating \(currSide) directory.")
    }
}

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
    nonisolated let appState: AppState
    var fileLst = FileSingleton.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let timeOutRefresh: Int = 12


    init(appState: AppState) {
        self.appState = appState
    }


    // MARK: - Starts timers for both directories with custom refresh intervals
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: PanelSide.right)
        setupTimer(for: PanelSide.left)
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }


    // MARK: -
    public func setRightDirectory(pathStr: String) {
        log.debug("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
    }
    // MARK: -
    public func setLeftDirectory(pathStr: String) {
        log.debug("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
    }

    // MARK: - Helper method to setup timers
    private func setupTimer(for side: PanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(timeOutRefresh))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshFiles(side: side)
            }
        }
        timer.resume()
        switch side {
            case .left: leftTimer = timer
            case .right: rightTimer = timer
        }
    }

    // MARK: - Refreshes the file list for a specific directory side
    private func refreshFiles(side: PanelSide) async {
        log.info(#function)
        do {
            switch side {
                case .left:
                    let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.leftPath))
                    await updateScannedFiles(scanned, for: .left)
                    await updateFileList(side: side, with: scanned)
                case .right:
                    let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.rightPath))
                    await updateScannedFiles(scanned, for: .right)
                    await updateFileList(side: side, with: scanned)
            }
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
        }
    }


    // MARK: -
    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for side: PanelSide) {
        log.info(#function)
        log.debug("Updating AppState.\(side)Panel with \(files.count) files.")
        switch side {
            case .left:
                appState.displayedLeftFiles = files
            case .right:
                appState.displayedRightFiles = files
        }
    }


    // MARK: - Updates the file list for the specified directory side
    private func updateFileList(side: PanelSide, with files: [CustomFile]) async {
        log.info(#function)
        log.debug("Updating left directory with \(files.count) files on \(String(describing: side)) side")
        switch side {
            case .left:
                await fileLst.updateLeftFiles(files)
            case .right:
                await fileLst.updateRightFiles(files)
        }
        log.debug("Finished updating \(String(describing: side)) directory.")
    }

}

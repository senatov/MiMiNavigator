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
actor DualDirectoryScanner {
    nonisolated let appState: AppState
    let interval = 15
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?

    init(appState: AppState) {
        self.appState = appState
    }

    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for side: PanelSide) {
        switch side {
        case .left:
            log.info("Updating AppState.leftPanel with \(files.count) files.")
            Task { @MainActor in
                await refreshFiles(side: side)
            }
            appState.displayedLeftFiles = files
        case .right:
            log.info("Updating AppState.rightPanel with \(files.count) files.")
            Task { @MainActor in
                await refreshFiles(side: side)
            }
            appState.displayedRightFiles = files
        }
    }

    // MARK: - Starts timers for both directories with custom refresh intervals
    func startMonitoring(appState: AppState) {
        log.info(#function)
        setupTimer(for: PanelSide.right)
        setupTimer(for: PanelSide.left)
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: -
    public func setRightDirectory(pathStr: String) {
        log.info("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
    }
    // MARK: -
    public func setLeftDirectory(pathStr: String) {
        log.info("\(#function) pathStr: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
    }

    // MARK: - Helper method to setup timers
    private func setupTimer(for side: PanelSide) {
        log.info(#function)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(interval))
        Task {
            await self.refreshFiles(side: side)
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
    public func refreshFiles(side: PanelSide) async {
        log.info(#function)
        do {
            switch side {
            case .left:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.leftPath))
                await updateScannedFiles(scanned, for: .left)
            case .right:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.rightPath))
                await updateScannedFiles(scanned, for: .right)
            }
        } catch {
            log.error("Failed to scan \(side) directory: \(error.localizedDescription)")
        }
    }
}

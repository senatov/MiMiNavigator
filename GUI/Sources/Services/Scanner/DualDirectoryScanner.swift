// DualDirectoryScanner.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.12.24.
// Copyright © 2024 Senatov. All rights reserved.
// Description: Core actor state and lifecycle for dual-panel directory scanning.

import FileModelKit
import Foundation
import SwiftUI

actor DualDirectoryScanner {
    let appState: AppState
    var fileCache = FileCache.shared

    // MARK: - Timers

    var leftTimer: DispatchSourceTimer?
    var rightTimer: DispatchSourceTimer?

    // MARK: - FSEvents watchers

    var leftFSEvents: FSEventsDirectoryWatcher?
    var rightFSEvents: FSEventsDirectoryWatcher?

    var leftWatchedPath: String?
    var rightWatchedPath: String?

    // MARK: - Debounce / scan state

    var lastFSEventsPatch: [FavPanelSide: Date] = [:]
    let fsEventsDebounceInterval: TimeInterval = 120

    var scanInProgress: [FavPanelSide: Bool] = [.left: false, .right: false]
    var activeScanTask: [FavPanelSide: Task<Void, Never>] = [:]
    var scanGeneration: [FavPanelSide: Int] = [.left: 0, .right: 0]
    var lastFullScan: [FavPanelSide: Date] = [:]

    let scanCooldown: TimeInterval = 3
    let mountedVolumeScanTimeout: TimeInterval = 8
    let progressivePreviewThreshold = 150

    // MARK: - MainActor publish state

    @MainActor var lastUpdateTime: [FavPanelSide: Date] = [:]
    @MainActor var lastContentHashOnMain: [FavPanelSide: Int] = [:]
    @MainActor var lastPublishedPathOnMain: [FavPanelSide: String] = [:]

    // MARK: - Derived values

    var refreshInterval: Int {
        Int(AppConstants.Scanning.refreshInterval)
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        setupTimer(for: .left)
        setupTimer(for: .right)

        if leftTimer == nil || rightTimer == nil {
            log.error("[DualDirectoryScanner] Failed to initialize directory timers")
        }

        Task { @MainActor in
            let leftURL = appState.leftURL
            let rightURL = appState.rightURL
            await self.startFSEvents(for: .left, url: leftURL)
            await self.startFSEvents(for: .right, url: rightURL)
        }
    }

    func stopMonitoring() {
        leftTimer?.cancel()
        leftTimer = nil

        rightTimer?.cancel()
        rightTimer = nil

        stopFSEvents(for: .left)
        stopFSEvents(for: .right)
        cancelScan(for: .left)
        cancelScan(for: .right)

        log.info("[DualDirectoryScanner] stopMonitoring: all timers and FSEvents watchers stopped")
    }

    // MARK: - Panel directory updates

    func setRightDirectory(pathStr: String) {
        guard pathStr.hasPrefix("/") else {
            log.error("\(#function) rejected non-absolute path: '\(pathStr)'")
            return
        }

        log.info("\(#function) '\(pathStr)'")

        let url = URL(fileURLWithPath: pathStr)

        Task { @MainActor in
            appState.updatePath(url, for: .right)
        }

        startFSEvents(for: .right, url: url)
    }

    func setLeftDirectory(pathStr: String) {
        guard pathStr.hasPrefix("/") else {
            log.error("\(#function) rejected non-absolute path: '\(pathStr)'")
            return
        }

        log.info("\(#function) '\(pathStr)'")

        let url = URL(fileURLWithPath: pathStr)

        Task { @MainActor in
            appState.updatePath(url, for: .left)
        }

        startFSEvents(for: .left, url: url)
    }
}

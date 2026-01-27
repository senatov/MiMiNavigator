// DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Actor for concurrent directory scanning
actor DualDirectoryScanner {
    let appState: AppState
    var fileCache = FileCache.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    
    /// Refresh interval from centralized constants
    private var refreshInterval: Int {
        Int(AppConstants.Scanning.refreshInterval)
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Start monitoring both panels
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: .left)
        setupTimer(for: .right)
        
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize directory timers")
        }
    }

    // MARK: - Set directory for right panel
    func setRightDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
    }

    // MARK: - Set directory for left panel
    func setLeftDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
    }

    // MARK: - Setup refresh timer for a panel
    private func setupTimer(for side: PanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(refreshInterval))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshFiles(currSide: side)
            }
        }
        timer.resume()
        
        switch side {
        case .left: leftTimer = timer
        case .right: rightTimer = timer
        }
    }

    // MARK: - Refresh files for a panel
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        log.verbose("\(#function) side: <<\(currSide)>>")
        
        let (path, showHidden): (String, Bool) = await MainActor.run {
            let p = currSide == .left ? appState.leftPath : appState.rightPath
            let h = UserPreferences.shared.snapshot.showHiddenFiles
            return (p, h)
        }
        
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        
        do {
            let scanned = try FileScanner.scan(url: resolvedURL, showHiddenFiles: showHidden)
            await updateScannedFiles(scanned, for: currSide)
            await updateFileList(panelSide: currSide, with: scanned)
        } catch let error as NSError {
            if isPermissionDeniedError(error) {
                log.warning("Permission denied for \(resolvedURL.path), requesting access...")
                let granted = await requestAndRetryAccess(for: resolvedURL, side: currSide)
                if !granted {
                    log.error("User denied access to \(resolvedURL.path)")
                }
            } else {
                log.error("Scan failed for <<\(currSide)>>: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Check if error is permission denied
    private func isPermissionDeniedError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }
        return false
    }
    
    // MARK: - Request access and retry scan
    private func requestAndRetryAccess(for url: URL, side: PanelSide) async -> Bool {
        let granted = await BookmarkStore.shared.requestAccessPersisting(for: url)
        guard granted else { return false }
        
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            await updateScannedFiles(scanned, for: side)
            await updateFileList(panelSide: side, with: scanned)
            log.info("Successfully scanned \(url.path) after access granted")
            return true
        } catch {
            log.error("Scan still failed after access granted: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Update displayed files
    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for side: PanelSide) {
        let sorted = appState.applySorting(files)
        switch side {
        case .left: appState.displayedLeftFiles = sorted
        case .right: appState.displayedRightFiles = sorted
        }
    }

    // MARK: - Reset timer for a panel
    func resetRefreshTimer(for side: PanelSide) {
        switch side {
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

    // MARK: - Update file list in storage
    @MainActor
    private func updateFileList(panelSide: PanelSide, with files: [CustomFile]) async {
        switch panelSide {
        case .left: await fileCache.updateLeftFiles(files)
        case .right: await fileCache.updateRightFiles(files)
        }
    }
}

//
// DualDirScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//
import Foundation
import SwiftUI

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

    // MARK: -
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: .right)
        setupTimer(for: .left)
        if leftTimer == nil || rightTimer == nil {
            log.error("failed to init timers")
        }
    }

    // MARK: -
    func setRightDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
    }

    // MARK: -
    func setLeftDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
    }

    // MARK: -
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

    // MARK: - Refresh files for a panel, requesting access if permission denied
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        log.info(#function + " side: <<\(currSide)>>")
        
        let path: String
        switch currSide {
        case .left:
            path = await MainActor.run { appState.leftPath }
        case .right:
            path = await MainActor.run { appState.rightPath }
        }
        
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        
        do {
            let scanned = try FileScanner.scan(url: resolvedURL)
            await updateScannedFiles(scanned, for: currSide)
            await updateFileList(panelSide: currSide, with: scanned)
        } catch let error as NSError {
            // Check for permission denied error (Code 257 or POSIX 13)
            if isPermissionDeniedError(error) {
                log.warning("Permission denied for \(resolvedURL.path), requesting access...")
                let granted = await requestAndRetryAccess(for: resolvedURL, side: currSide)
                if !granted {
                    log.error("User denied access to \(resolvedURL.path)")
                }
            } else {
                log.error("scan failed <<\(currSide)>>: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Check if error is permission denied
    private func isPermissionDeniedError(_ error: NSError) -> Bool {
        // NSCocoaErrorDomain Code=257 (NSFileReadNoPermissionError)
        if error.domain == NSCocoaErrorDomain && error.code == 257 {
            return true
        }
        // NSPOSIXErrorDomain Code=13 (EACCES)
        if error.domain == NSPOSIXErrorDomain && error.code == 13 {
            return true
        }
        // Check underlying error
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }
        return false
    }
    
    // MARK: - Request access via dialog and retry scan
    private func requestAndRetryAccess(for url: URL, side: PanelSide) async -> Bool {
        // Request access on MainActor (shows NSOpenPanel)
        let granted = await BookmarkStore.shared.requestAccessPersisting(for: url)
        
        guard granted else {
            return false
        }
        
        // Retry scanning after access granted
        do {
            let scanned = try FileScanner.scan(url: url)
            await updateScannedFiles(scanned, for: side)
            await updateFileList(panelSide: side, with: scanned)
            log.info("Successfully scanned \(url.path) after access granted")
            return true
        } catch {
            log.error("Scan still failed after access granted: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: -
    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for currSide: PanelSide) {
        log.info(#function + " side: \(currSide)")
        log.info("updating AppState.\(currSide) w/ \(files.count) files")
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
        log.info(#function + " side: <<\(currSide)>>")
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

    // MARK: -
    @MainActor
    private func updateFileList(panelSide: PanelSide, with files: [CustomFile]) async {
        log.info(#function + " side: <<\(panelSide)>>")
        
        // Always update file list, even if selectedEntity is nil
        // (e.g., when user manually enters a path)
        if let selectedEntity = appState.selectedDir.selectedFSEntity {
            log.info("updating sel'd dir: \(selectedEntity.pathStr) w/ \(files.count) files on <<\(panelSide)>>")
        } else {
            log.info("updating w/ \(files.count) files on <<\(panelSide)>> (no selectedEntity)")
        }
        
        switch panelSide {
            case .left:
                await fileLst.updateLeftFiles(files)
            case .right:
                await fileLst.updateRightFiles(files)
        }
        log.info("finished updating <<\(panelSide)>>")
    }
}

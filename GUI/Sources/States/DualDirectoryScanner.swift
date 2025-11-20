//
// DualDirScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//
import Combine
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

    // MARK: -
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        log.info(#function + " side: <<\(currSide)>>")
        do {
            switch currSide {
            case .left:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.leftPath))
                await updateScannedFiles(scanned, for: .left)
                await updateFileList(panelSide: .left, with: scanned)

            case .right:
                let scanned = try await FileScanner.scan(url: URL(fileURLWithPath: appState.rightPath))
                await updateScannedFiles(scanned, for: .right)
                await updateFileList(panelSide: .right, with: scanned)
            }
        }
        catch {
            log.error("scan failed <<\(currSide)>>: \(error.localizedDescription)")
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
        guard let selectedEntity = appState.selectedDir.selectedFSEntity else {
            log.warning("no sel'd FSEntity for <<\(panelSide)>>")
            return
        }
        log.info("updating sel'd dir: \(selectedEntity.pathStr) w/ \(files.count) files on <<\(panelSide)>>")
        switch panelSide {
        case .left:
            await fileLst.updateLeftFiles(files)
        case .right:
            await fileLst.updateRightFiles(files)
        }
        log.info("finished updating <<\(panelSide)>>")
    }
}

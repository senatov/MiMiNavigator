// AppState+SearchResults.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Search results display, clear, archive repack confirmation

import AppKit
import FileModelKit
import Foundation

// MARK: - Search Results
extension AppState {

    func isShowingSearchResults(on panel: FavPanelSide) -> Bool {
        self[panel: panel].searchResultsPath != nil
    }

    func showSearchResults(_ files: [CustomFile], virtualPath: String, on panel: FavPanelSide) {
        let sorted = applySorting(files)
        log.debug(#function + ": \(sorted.count) files")
        self[panel: panel].searchResultsPath = virtualPath
        if panel == .left { displayedLeftFiles = sorted } else { displayedRightFiles = sorted }
        setPath(virtualPath, for: panel)
        setSelectedFile(firstRealFile(in: sorted), for: panel)
        focusedPanel = panel
    }

    func clearSearchResults(on panel: FavPanelSide) {
        guard isShowingSearchResults(on: panel) else { return }
        let archivePaths = searchResultArchives[panel] ?? []
        if !archivePaths.isEmpty {
            Task { @MainActor in
                for archivePath in archivePaths {
                    let archiveURL = URL(fileURLWithPath: archivePath)
                    let isDirty = await ArchiveManager.shared.isDirty(archiveURL: archiveURL)
                    if isDirty {
                        let shouldRepack = await confirmRepackSearchResult(archiveName: archiveURL.lastPathComponent)
                        try? await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: shouldRepack)
                    } else {
                        try? await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: false)
                    }
                }
                self.searchResultArchives[panel] = nil
                self.finishClearSearchResults(on: panel)
            }
        } else {
            searchResultArchives[panel] = nil
            finishClearSearchResults(on: panel)
        }
    }

    private func finishClearSearchResults(on panel: FavPanelSide) {
        let history = navigationHistory(for: panel)
        let previousPath = history.currentPath?.path ?? NSHomeDirectory()
        self[panel: panel].searchResultsPath = nil
        updatePath(previousPath, for: panel)
        Task {
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: previousPath)
            } else {
                await scanner.setRightDirectory(pathStr: previousPath)
            }
            await refreshFiles(for: panel)
        }
    }

    @MainActor
    private func confirmRepackSearchResult(archiveName: String) async -> Bool {
        ErrorAlertService.confirm(
            title: "Archive Modified",
            message: "\"\(archiveName)\" was modified while viewing search results.\n\nRepack?",
            confirmButton: "Repack",
            cancelButton: "Discard Changes"
        )
    }
}

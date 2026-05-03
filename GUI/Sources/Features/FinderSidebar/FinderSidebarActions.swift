// FinderSidebarActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Finder Sidebar Actions
extension FinderSidebarView {
    // MARK: - Handle Item
    func handle(_ item: FinderSidebarItem) {
        selectedID = item.id
        log.info("[FinderSidebar] open title='\(item.title)' target='\(item.identityKey)'")
        switch item.action {
        case .airDrop:
            openAirDrop()
        case .network:
            NetworkNeighborhoodCoordinator.shared.toggle()
        case .history:
            openHistory()
        case .navigate(let url):
            navigate(to: url)
        case .openIfExists(let url):
            openIfExists(url)
        }
    }

    // MARK: - Navigate
    func navigate(to url: URL) {
        if AppState.isRemotePath(url) {
            Task { @MainActor in
                let panel = appState.focusedPanel
                appState.updatePath(url, for: panel)
                await appState.refreshRemoteFiles(for: panel)
                log.info("[FinderSidebar] navigate remote panel=\(panel) url='\(url.absoluteString)'")
            }
            return
        }
        if !url.isFileURL {
            log.info("[FinderSidebar] open external url='\(url.absoluteString)'")
            NSWorkspace.shared.open(url)
            return
        }
        Task { @MainActor in
            let panel = appState.focusedPanel
            appState.updatePath(url, for: panel)
            await appState.scanner.clearCooldown(for: panel)
            await appState.scanner.refreshFiles(currSide: panel, force: true)
            log.info("[FinderSidebar] navigate panel=\(panel) path='\(url.path)'")
        }
    }

    // MARK: - Open If Exists
    func openIfExists(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            log.warning("[FinderSidebar] missing path='\(url.path)'")
            return
        }
        if isDirectory.boolValue {
            navigate(to: url)
        } else {
            log.info("[FinderSidebar] open file path='\(url.path)'")
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Open Console
    func openConsole(for item: FinderSidebarItem) {
        let url = item.fileURL ?? appState.pathURL(for: appState.focusedPanel) ?? URL(fileURLWithPath: "/")
        log.info("[FinderSidebar] console path='\(url.path)'")
        CntMenuCoord.shared.openTerminal(at: url)
    }

    // MARK: - Open AirDrop
    func openAirDrop() {
        guard let url = URL(string: "airdrop://") else { return }
        log.info("[FinderSidebar] open AirDrop")
        NSWorkspace.shared.open(url)
    }

    // MARK: - Open History
    func openHistory() {
        let panel = appState.focusedPanel
        let content = HistoryWindowContent(panelSide: panel)
            .environment(appState)
        log.info("[FinderSidebar] open history panel=\(panel)")
        PanelDialogCoordinator.history.open(content: content)
    }

    // MARK: - Refresh Sources
    func refreshSidebarSources() {
        refreshVolumes()
        log.info("[FinderSidebar] sources loaded volumes=\(volumes.count) cachedGroups=\(favoritesStore.systemFavorites.count)")
    }

    // MARK: - Refresh Volumes
    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        volumes = urls.compactMap(volumeItem)
        log.debug("[FinderSidebar] volumes refreshed count=\(volumes.count)")
    }

    // MARK: - Unmount
    func unmount(_ item: FinderSidebarItem) {
        guard let url = item.fileURL, item.canUnmount else {
            log.warning("[FinderSidebar] unmount rejected title='\(item.title)'")
            return
        }
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            log.info("[FinderSidebar] unmounted title='\(item.title)' path='\(url.path)'")
            refreshVolumes()
        } catch {
            log.error("[FinderSidebar] unmount failed title='\(item.title)' path='\(url.path)' error='\(error.localizedDescription)'")
        }
    }

    // MARK: - Copy Path
    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        log.info("[FinderSidebar] copied path='\(url.path)'")
    }
}

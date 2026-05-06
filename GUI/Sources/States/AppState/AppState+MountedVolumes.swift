// AppState+MountedVolumes.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Mounted external volume handling.

import AppKit
import Foundation

// MARK: - Mounted Volumes
extension AppState {

    // MARK: - Observer
    func startMountedVolumeObserver() {
        guard mountedVolumeObserver == nil else { return }
        mountedVolumeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Notification.Name("NSWorkspaceDidMountNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = Self.mountedVolumeURL(from: notification) else { return }
            Task { @MainActor [weak self] in
                await self?.handleMountedExternalVolume(url)
            }
        }
        log.info("[Volumes] mount observer started")
    }

    // MARK: - Handle Mount
    func handleMountedExternalVolume(_ url: URL) async {
        guard Self.shouldAutoOpenMountedVolume(url) else {
            log.debug("[Volumes] mount ignored path='\(url.path)'")
            return
        }
        log.info("[Volumes] auto-open left panel path='\(url.path)'")
        focusedPanel = .left
        await navigateToDirectory(url.path, on: .left)
    }

    // MARK: - Notification URL
    nonisolated static func mountedVolumeURL(from notification: Notification) -> URL? {
        notification.userInfo?["NSWorkspaceVolumeURLKey"] as? URL
    }

    // MARK: - Auto Open Filter
    nonisolated static func shouldAutoOpenMountedVolume(_ url: URL) -> Bool {
        guard url.isFileURL, isMountedVolumeRootPath(url.path) else { return false }
        let keys: Set<URLResourceKey> = [
            .volumeIsEjectableKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey,
            .volumeIsRemovableKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        if values.volumeIsInternal == true { return false }
        if values.volumeIsLocal == false { return false }
        if values.volumeIsEjectable == true || values.volumeIsRemovable == true { return true }
        return true
    }
}

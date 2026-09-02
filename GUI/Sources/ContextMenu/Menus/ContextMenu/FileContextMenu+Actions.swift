// FileContextMenu+Actions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Action handling and state for FileContextMenu.

import FavoritesKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Actions

extension FileContextMenu {
    // MARK: - Snapshot
    func makeSnapshot() -> DebugSnapshot {
        logSnapshot
    }

    // MARK: - Logging
    func logBodyAppearance() {
        let snapshot = makeSnapshot()
        FileContextMenuLog.logBody(prefix: debugPrefix, snapshot: snapshot)
    }

    func logAction(_ action: FileAction, snapshot: DebugSnapshot) {
        FileContextMenuLog.logAction(prefix: debugPrefix, action: action.rawValue, snapshot: snapshot)
    }

    // MARK: - Perform Action
    func performAction(_ action: FileAction) {
        let snapshot = makeSnapshot()
        logAction(action, snapshot: snapshot)
        onAction(action)
    }

    // MARK: - State
    func isActionDisabled(_ action: FileAction) -> Bool {
        switch action {
        case .paste:
            let disabled = !ClipboardManager.shared.hasContent
            log.debug("[FileContextMenu] paste availability file='\(file.nameStr)' hasContent=\(!disabled)")
            return disabled
        default:
            return false
        }
    }

    // MARK: - Static Helpers
    @MainActor
    static func makeNextDebugID() -> Int {
        nextDebugID += 1
        return nextDebugID
    }

    @MainActor
    static func loadOpenWithApps(for file: CustomFile) -> [AppInfo] {
        let cacheKey = cacheKey(for: file)
        if let cachedApps = OpenWithCache.cachedApps(for: file) {
            FileContextMenuLog.logOpenWithCacheHit(cacheKey)
            return cachedApps
        }
        FileContextMenuLog.logOpenWithCacheMiss(cacheKey)
        let loadedApps = OpenWithService.shared.getApplications(for: file.urlValue)
        OpenWithCache.store(loadedApps, for: file)
        return loadedApps
    }

    static func makeOpenWithMenuID(for file: CustomFile, apps: [AppInfo]) -> String {
        let submenuSignature = apps.map(\.bundleIdentifier).sorted().joined(separator: ",")
        return "openwith|\(file.urlValue.path)|\(submenuSignature)"
    }

    nonisolated static func isMediaFile(_ file: CustomFile) -> Bool {
        let fileExtension = file.urlValue.pathExtension.lowercased()
        let resolvedType = UTType(filenameExtension: fileExtension)
        let conformsToMediaType = resolvedType.map { type in
            FileContextMenuConfig.mediaConformingTypes.contains { type.conforms(to: $0) }
        } ?? false
        if conformsToMediaType {
            return true
        }
        return FileContextMenuConfig.isKnownMediaExtension(fileExtension)
    }
}

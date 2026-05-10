// DualDirectoryScanner+GeoTags.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Background GPS metadata detection for image badge overlays.

import FileModelKit
import Foundation
import ScannerKit

// MARK: - Geo-tag publishing
extension DualDirectoryScanner {

    // MARK: - Geo-tag scan scheduling
    @MainActor
    func scheduleGeoTagScan(_ files: [CustomFile], for side: FavPanelSide, path: String) {
        let filesToScan = files.filter { file in
            guard !ParentDirectoryEntry.isParentEntry(file), !appState.geoTaggedPaths.contains(file.pathStr) else { return false }
            return !file.isDirectory && GeoTagScanner.isGeoCapable(file.fileExtension)
        }
        guard !filesToScan.isEmpty else { return }
        log.debug("[GeoTag] scheduling scan side=\(side) files=\(filesToScan.count)")
        Task.detached(priority: .utility) {
            let taggedPaths = GeoTagScanner.detectGeoTaggedPaths(filesToScan)
            let scannedPaths = Set(filesToScan.map(\.pathStr))
            await self.applyGeoTaggedPaths(taggedPaths, scannedPaths: scannedPaths, for: side, path: path)
        }
    }

    // MARK: - Geo-tag scan result publishing
    @MainActor
    func applyGeoTaggedPaths(_ taggedPaths: Set<String>, scannedPaths: Set<String>, for side: FavPanelSide, path: String) {
        guard appState.path(for: side) == path else { return }
        let before = appState.geoTaggedPaths
        appState.geoTaggedPaths.subtract(scannedPaths)
        appState.geoTaggedPaths.formUnion(taggedPaths)
        guard appState.geoTaggedPaths != before else { return }
        GeoTagScanner.applyGeoTags(taggedPaths, to: displayedFilesBinding(for: side))
        log.debug("[GeoTag] applied \(taggedPaths.count) geotags side=\(side)")
        appState.bumpFilesVersion(for: side)
        log.debug("[GeoTag] bumped filesVersion side=\(side)")
    }
}

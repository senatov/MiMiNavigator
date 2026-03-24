//
//  PathNavigationService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation
import SwiftyBeaver

@MainActor
final class PathNavigationService {

    private var appState: AppState

    // MARK: - Singleton
    private static var _shared: PathNavigationService?

    static func shared(appState: AppState) -> PathNavigationService {
        if let existing = _shared {
            // AppState may be recreated (e.g. during view rebuilding). Keep service pointing to the latest instance.
            if existing.appState !== appState {
                log.debug("[PathNav] shared(): AppState instance changed, updating reference")
                existing.appState = appState
            }
            return existing
        }

        let instance = PathNavigationService(appState: appState)
        _shared = instance
        return instance
    }

    private init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Parsing
    private struct NavigationTarget {
        let urlForAppState: URL
        let pathForScanner: String
    }

    private func parseTarget(from input: String) -> NavigationTarget? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Remote URLs: keep as URL(string:) and pass absoluteString to scanner.
        if let remoteURL = URL(string: trimmed), isRemoteURL(remoteURL) {
            return NavigationTarget(urlForAppState: remoteURL, pathForScanner: remoteURL.absoluteString)
        }

        // Local: expand tilde and normalize.
        let expanded = (trimmed as NSString).expandingTildeInPath
        let fileURL: URL

        if let asURL = URL(string: expanded), asURL.isFileURL {
            fileURL = asURL
        } else {
            fileURL = URL(fileURLWithPath: expanded)
        }

        let normalizedDirURL = normalizeToDirectory(fileURL)
        return NavigationTarget(urlForAppState: normalizedDirURL, pathForScanner: normalizedDirURL.path)
    }

    private func isRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        switch scheme {
            case "smb", "afp", "ftp", "ftps", "sftp", "ssh":
                return true
            default:
                return false
        }
    }

    private func normalizeToDirectory(_ url: URL) -> URL {
        // If user points to a file, navigate to its parent directory.
        if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == false {
            return url.deletingLastPathComponent().standardizedFileURL
        }
        return url.standardizedFileURL
    }

    // MARK: - Public API

    /// Navigate to a new path (used by breadcrumb, manual input, etc.)
    func navigate(to path: String, side: FavPanelSide) async {
        guard let target = parseTarget(from: path) else {
            log.warning("[PathNav] invalid input: '\(path)'")
            return
        }
        guard validate(target: target) else {
            log.warning("[PathNav] invalid target: \(target.pathForScanner)")
            return
        }
        log.info("[PathNav] navigating \(side) → \(target.pathForScanner)")
        // 1. Update AppState (history + UI)
        appState.updatePath(target.urlForAppState, for: side)
        // 2. Apply to scanner
        await setDirectory(path: target.pathForScanner, side: side)
        // 3. Force refresh (user navigation)
        await refresh(side: side)
    }

    private func validate(target: NavigationTarget) -> Bool {
        // Remote URLs are assumed navigable here.
        if let url = URL(string: target.pathForScanner), isRemoteURL(url) {
            return true
        }

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: target.pathForScanner, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - Scanner integration

    private func setDirectory(path: String, side: FavPanelSide) async {
        switch side {
            case .left:
                await appState.scanner.setLeftDirectory(pathStr: path)
            case .right:
                await appState.scanner.setRightDirectory(pathStr: path)
        }
    }

    private func refresh(side: FavPanelSide) async {
        // Force refresh because user explicitly navigated
        await appState.scanner.forceRefreshAfterFileOp(side: side)

        switch side {
            case .left:
                await appState.refreshLeftFiles()
            case .right:
                await appState.refreshRightFiles()
        }
    }
}

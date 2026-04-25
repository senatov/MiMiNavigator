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
        let displayPath: String?
    }

    private func parseTarget(from input: String) -> NavigationTarget? {
        let trimmed = parsedInput(input)
        guard !trimmed.isEmpty else { return nil }

        // Remote URLs: keep as URL(string:) and pass absoluteString to scanner.
        if let remoteURL = URL(string: trimmed), isRemoteURL(remoteURL) {
            return makeRemoteTarget(from: remoteURL)
        }

        // Local: expand tilde/environment variables and normalize.
        return makeLocalTarget(from: trimmed)
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
        let standardizedURL = url.standardizedFileURL
        let resolvedURL = standardizedURL.resolvingSymlinksInPath()

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return standardizedURL
            }
            return standardizedURL.deletingLastPathComponent().standardizedFileURL
        }

        // Fallback for non-existing paths: preserve the typed directory path.
        return standardizedURL
    }

    private func makeRemoteTarget(from remoteURL: URL) -> NavigationTarget {
        makeNavigationTarget(url: remoteURL, scannerPath: remoteURL.absoluteString)
    }

    private func expandedLocalInput(_ input: String) -> (path: String, displayPath: String?)? {
        guard let expansion = PathEnvironmentResolver.expand(input) else { return nil }
        let expanded = (expansion.expanded as NSString).expandingTildeInPath
        return (expanded, expansion.containsVariable ? expansion.original : nil)
    }

    private func localFileURL(from input: String) -> URL? {
        guard let resolved = expandedLocalInput(input) else { return nil }
        let expanded = resolved.path
        if let url = URL(string: expanded), url.isFileURL {
            return url
        }
        return URL(fileURLWithPath: expanded)
    }

    private func makeLocalTarget(from input: String) -> NavigationTarget {
        guard let fileURL = localFileURL(from: input),
              let resolved = expandedLocalInput(input)
        else {
            return makeNavigationTarget(url: URL(fileURLWithPath: input), scannerPath: input, displayPath: nil)
        }
        let normalizedDirURL = normalizeToDirectory(fileURL)
        let normalizedDisplayPath = resolved.displayPath.flatMap {
            PathEnvironmentResolver.symbolicPath(forResolvedPath: normalizedDirURL.path, preserving: $0) ?? $0
        }
        return makeNavigationTarget(
            url: normalizedDirURL,
            scannerPath: normalizedDirURL.path,
            displayPath: normalizedDisplayPath
        )
    }

    private func isRemoteTarget(_ target: NavigationTarget) -> Bool {
        guard let url = URL(string: target.pathForScanner) else { return false }
        return isRemoteURL(url)
    }

    private func parsedInput(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeNavigationTarget(url: URL, scannerPath: String, displayPath: String? = nil) -> NavigationTarget {
        NavigationTarget(urlForAppState: url, pathForScanner: scannerPath, displayPath: displayPath)
    }

    // MARK: - Public API

    /// Navigate to a new path (used by breadcrumb, manual input, etc.)
    func navigate(to path: String, side: FavPanelSide) async {
        guard let target = parseTarget(from: path) else {
            logInvalidInput(path)
            return
        }
        guard validate(target: target) else {
            log.warning("[PathNav] invalid target: \(target.pathForScanner)")
            return
        }
        log.info("[PathNav] navigating \(side) → \(target.pathForScanner)")

        if isRemoteTarget(target) {
            await navigateToRemoteTarget(target, side: side)
            return
        }
        // Local: update AppState + scanner + refresh as before.
        await applyLocalTarget(target, side: side)
    }

    private func logInvalidInput(_ path: String) {
        log.warning("[PathNav] invalid input: '\(path)'")
    }

    private func navigateToRemoteTarget(_ target: NavigationTarget, side: FavPanelSide) async {
        // Remote URLs: use navigateToDirectory which handles SFTP/FTP correctly.
        // Do NOT pass remote URL to scanner — scanner only handles local paths.
        await appState.navigateToDirectory(target.pathForScanner, on: side)
    }

    private func isValidLocalDirectoryPath(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func validate(target: NavigationTarget) -> Bool {
        // Remote URLs are assumed navigable here.
        if isRemoteTarget(target) {
            return true
        }

        return isValidLocalDirectoryPath(target.pathForScanner)
    }

    private func applyLocalTarget(_ target: NavigationTarget, side: FavPanelSide) async {
        if PathUtils.areEqual(appState.url(for: side), target.urlForAppState),
           !appState.displayedFiles(for: side).isEmpty
        {
            log.info("[PathNav] skip redundant local navigation \(side) → \(target.pathForScanner)")
            return
        }

        appState.updateKnownDirectoryPath(target.urlForAppState, for: side, displayPath: target.displayPath)
        await setDirectory(path: target.pathForScanner, side: side)
        await refresh(side: side)
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

    private func refreshPanel(_ side: FavPanelSide) async {
        switch side {
            case .left:
                await appState.refreshLeftFiles()
            case .right:
                await appState.refreshRightFiles()
        }
    }

    private func forceRefreshScanner(_ side: FavPanelSide) async {
        await appState.scanner.forceRefreshAfterFileOp(side: side)
    }

    private func refresh(side: FavPanelSide) async {
        // Force refresh because user explicitly navigated.
        await forceRefreshScanner(side)
        await refreshPanel(side)
    }
}

// DropboxShareService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Copies items to Dropbox Public and creates short view-only links.

import AppKit
import Foundation

// MARK: - DropboxShareService

@MainActor
enum DropboxShareService {
    // MARK: - Copy Share Link

    static func copyShareLink(for sourceURL: URL) async -> Bool {
        let panel = ProgressPanel.shared
        panel.show(
            icon: "link.badge.plus",
            title: "Share+Link: \(sourceURL.lastPathComponent)",
            status: "Authenticating with Dropbox…",
            operationKey: "dropbox-share",
            cancelHandler: { CloudLinkService.cancelActiveShare() }
        )
        panel.updateProgress(nil)
        panel.appendKeyValueLog("Source", value: sourceURL.path)
        var createdDestination: URL?
        do {
            guard let publicFolder = DropboxMountedPaths.publicFolderURL() else { throw DropboxError.missingPublicFolder }
            panel.appendLog("Authenticating with Dropbox…")
            let token = try await DropboxOAuthClient.accessToken()
            try Task.checkCancellation()
            let destination = uniqueDestination(for: sourceURL, in: publicFolder)
            panel.appendLog("Copying item to Dropbox Public…")
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            createdDestination = destination
            panel.appendLog("Waiting for Dropbox sync and creating public link…")
            let path = "/Public/\(destination.lastPathComponent)"
            let originalLink = try await DropboxAPIClient(accessToken: token).sharedLink(for: path)
            try Task.checkCancellation()
            panel.appendLog("Creating MiMiNavi short link…")
            let copiedLink: String
            let copiedLinkLabel: String
            do {
                copiedLink = try await CloudLinkShortener.shorten(originalLink)
                copiedLinkLabel = "Short link"
            } catch {
                copiedLink = originalLink
                copiedLinkLabel = "Share link"
                panel.appendLog("⚠️ TinyURL could not create a short link; using the original Dropbox link.")
                log.warning("[CloudLink] TinyURL fallback host='\(URL(string: originalLink)?.host ?? "unknown")': \(error.localizedDescription)")
            }
            copyToClipboard(copiedLink)
            panel.appendKeyValueLog("Dropbox path", value: path)
            panel.appendKeyValueLog(copiedLinkLabel, value: copiedLink)
            panel.finish(success: true, message: "Share+Link ready: link copied to clipboard")
            FileOperationOutcomePresenter.success(
                .shareLink,
                resultURL: URL(string: copiedLink),
                displayName: "for \(sourceURL.lastPathComponent)"
            )
            log.info("[CloudLink] Dropbox link copied path='\(path)' link='\(copiedLink)'")
            return true
        } catch is CancellationError {
            removeCreatedDestination(createdDestination, panel: panel)
            panel.finish(success: false, message: "Share+Link cancelled")
            FileOperationOutcomePresenter.cancelled(.shareLink)
            log.info("[CloudLink] Dropbox share cancelled")
            return false
        } catch {
            removeCreatedDestination(createdDestination, panel: panel)
            panel.appendLog("❌ \(error.localizedDescription)")
            panel.finish(success: false, message: "Dropbox Share+Link failed")
            FileOperationOutcomePresenter.failure(.shareLink, error: error)
            log.error("[CloudLink] Dropbox share failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Destination

    private static func uniqueDestination(for source: URL, in folder: URL) -> URL {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory)
        let sourceIsDirectory = isDirectory.boolValue
        let initial = folder.appendingPathComponent(source.lastPathComponent, isDirectory: sourceIsDirectory)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        let stem = sourceIsDirectory ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        let ext = sourceIsDirectory ? "" : source.pathExtension
        for index in 2...999 {
            let name = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(name, isDirectory: sourceIsDirectory)
            if FileManager.default.fileExists(atPath: candidate.path) == false {
                return candidate
            }
        }
        let fallbackName = ext.isEmpty ? "\(stem) \(UUID().uuidString)" : "\(stem) \(UUID().uuidString).\(ext)"
        return folder.appendingPathComponent(fallbackName, isDirectory: sourceIsDirectory)
    }

    // MARK: - Cleanup

    private static func removeCreatedDestination(_ destination: URL?, panel: ProgressPanel) {
        guard let destination else { return }
        do {
            try FileManager.default.removeItem(at: destination)
            panel.appendLog("Removed the incomplete Dropbox copy.")
            log.info("[CloudLink] removed failed Dropbox copy path='\(destination.path)'")
        } catch {
            panel.appendLog("⚠️ Could not remove the incomplete Dropbox copy.")
            log.warning("[CloudLink] failed to remove Dropbox copy path='\(destination.path)': \(error.localizedDescription)")
        }
    }

    // MARK: - Clipboard

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

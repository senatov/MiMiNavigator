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
        panel.show(icon: "link.badge.plus", title: "Share+Link: \(sourceURL.lastPathComponent)", status: "Copying to Dropbox…", operationKey: "dropbox-share")
        panel.updateProgress(nil)
        panel.appendKeyValueLog("Source", value: sourceURL.path)
        do {
            guard let publicFolder = DropboxMountedPaths.publicFolderURL() else { throw DropboxError.missingPublicFolder }
            panel.appendLog("Authenticating with Dropbox…")
            let token = try await DropboxOAuthClient.accessToken()
            let destination = uniqueDestination(for: sourceURL, in: publicFolder)
            panel.appendLog("Copying item to Dropbox Public…")
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            panel.appendLog("Waiting for Dropbox sync and creating public link…")
            let path = "/Public/\(destination.lastPathComponent)"
            let originalLink = try await DropboxAPIClient(accessToken: token).sharedLink(for: path)
            panel.appendLog("Creating MiMiNavi short link…")
            let clipboardLink = await shortenedLink(or: originalLink, panel: panel)
            copyToClipboard(clipboardLink)
            panel.appendKeyValueLog("Dropbox path", value: path)
            panel.appendKeyValueLog("Public link", value: originalLink)
            if clipboardLink != originalLink {
                panel.appendKeyValueLog("Short link", value: clipboardLink)
            }
            panel.finish(success: true, message: "Share+Link ready: link copied to clipboard")
            log.info("[CloudLink] Dropbox link copied path='\(path)' link='\(clipboardLink)'")
            return true
        } catch {
            panel.appendLog("❌ \(error.localizedDescription)")
            panel.finish(success: false, message: "Dropbox Share+Link failed")
            log.error("[CloudLink] Dropbox share failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Destination

    private static func uniqueDestination(for source: URL, in folder: URL) -> URL {
        let initial = folder.appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        for index in 2...999 {
            let name = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(name, isDirectory: source.hasDirectoryPath)
            if FileManager.default.fileExists(atPath: candidate.path) == false {
                return candidate
            }
        }
        let fallbackName = ext.isEmpty ? "\(stem) \(UUID().uuidString)" : "\(stem) \(UUID().uuidString).\(ext)"
        return folder.appendingPathComponent(fallbackName, isDirectory: source.hasDirectoryPath)
    }

    // MARK: - Short Link

    private static func shortenedLink(or link: String, panel: ProgressPanel) async -> String {
        do {
            let shortLink = try await CloudLinkShortener.shorten(link)
            panel.appendLog("MiMiNavi short link created.")
            return shortLink
        } catch {
            panel.appendLog("Short link unavailable; using the original Dropbox link.")
            log.warning("[CloudLink] Dropbox short link failed: \(error.localizedDescription)")
            return link
        }
    }

    // MARK: - Clipboard

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

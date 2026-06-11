// CloudLinkService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Generates shareable cloud links for files/directories
//   in iCloud Drive, OneDrive, Google Drive, Dropbox.
//   Copies link to clipboard or opens web UI for providers
//   that don't support direct link generation.

import AppKit
import Foundation


// MARK: - CloudLinkPermission

enum CloudLinkPermission: String, Sendable {
    case readOnly  = "view"
    case allowEdit = "edit"
}


// MARK: - CloudLinkService

@MainActor
enum CloudLinkService {

    /// Generate or open cloud link for the given URL.
    /// Returns true if a link was copied to clipboard, false if web UI was opened instead.
    @discardableResult
    static func generateLink(for url: URL, provider: CloudProvider, permission: CloudLinkPermission) -> Bool {
        log.info("[CloudLink] \(provider.rawValue) \(permission.rawValue) for \(url.lastPathComponent)")
        switch provider {
        case .dropbox:
            return dropboxLink(url: url, permission: permission)
        case .iCloud:
            return iCloudLink(url: url)
        case .oneDrive:
            return oneDriveLink(url: url, permission: permission)
        case .googleDrive:
            return googleDriveLink(url: url, permission: permission)
        }
    }



    // MARK: - Dropbox
    /// Dropbox link generation requires MiMiNavigator Dropbox OAuth credentials.
    private static func dropboxLink(url: URL, permission: CloudLinkPermission) -> Bool {
        guard permission == .readOnly else { return false }
        log.warning("[CloudLink] Dropbox OAuth app key is not configured for \(url.lastPathComponent)")
        showNotification("Dropbox Share+Link requires a MiMiNavigator Dropbox App Key.")
        return false
    }



    // MARK: - iCloud Drive
    /// iCloud doesn't have CLI link gen — open iCloud Drive web UI
    private static func iCloudLink(url: URL) -> Bool {
        // Apple provides no public API for iCloud sharing links programmatically.
        // Best we can do: open iCloud Drive in browser
        openInBrowser("https://www.icloud.com/iclouddrive/")
        showNotification("iCloud Drive opened in browser. Use Share button in web UI to generate link.")
        return false
    }



    // MARK: - OneDrive
    /// OneDrive needs Microsoft Graph auth to create a real sharing URL.
    private static func oneDriveLink(url: URL, permission: CloudLinkPermission) -> Bool {
        log.info("[CloudLink] OneDrive Graph sharing is not configured for \(url.lastPathComponent), permission=\(permission.rawValue)")
        showNotification("OneDrive sharing link requires Microsoft Graph sign-in.")
        return false
    }



    // MARK: - Google Drive
    /// Google Drive — open web UI
    private static func googleDriveLink(url: URL, permission: CloudLinkPermission) -> Bool {
        Task {
            await GoogleDriveShareService.copyShareLink(for: url, permission: permission)
        }
        return true
    }



    // MARK: - Helpers

    private static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }



    private static func openInBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            log.error("[CloudLink] invalid URL: \(urlString)")
            return
        }
        NSWorkspace.shared.open(url)
    }



    private static func showNotification(_ message: String) {
        log.info("[CloudLink] \(message)")
        // TODO: replace with in-app toast/banner when available
    }



    /// Extract relative path within cloud storage folder
    private static func extractCloudRelativePath(from fullPath: String, storagePrefix: String, providerPrefix: String) -> String {
        // Path pattern: ~/Library/CloudStorage/OneDrive-Personal/some/path
        guard fullPath.contains(storagePrefix) else { return fullPath }
        let afterStorage = fullPath.replacingOccurrences(of: storagePrefix, with: "")
        // skip "OneDrive-Personal/" or "GoogleDrive-email@/" prefix
        let components = afterStorage.split(separator: "/", maxSplits: 1)
        guard components.count > 1,
              components[0].hasPrefix(providerPrefix) else {
            return afterStorage
        }
        return String(components[1])
    }
}

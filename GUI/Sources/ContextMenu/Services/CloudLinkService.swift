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
    /// Dropbox CLI supports direct link generation via `dropbox sharelink`
    private static func dropboxLink(url: URL, permission: CloudLinkPermission) -> Bool {
        // try Dropbox CLI first (official Dropbox app installs it)
        let dbCLI = "/Applications/Dropbox.app/Contents/MacOS/dropbox"
        let altCLI = "/usr/local/bin/dropbox"
        let cli = FileManager.default.fileExists(atPath: dbCLI) ? dbCLI : altCLI
        guard FileManager.default.fileExists(atPath: cli) else {
            log.warning("[CloudLink] Dropbox CLI not found, opening web")
            openDropboxWeb(url: url)
            return false
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cli)
        proc.arguments = ["sharelink", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let link = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !link.isEmpty {
                let finalLink = applyDropboxPermission(link, permission: permission)
                copyToClipboard(finalLink)
                log.info("[CloudLink] Dropbox link copied: \(finalLink)")
                return true
            }
        } catch {
            log.warning("[CloudLink] Dropbox CLI error: \(error.localizedDescription)")
        }
        openDropboxWeb(url: url)
        return false
    }



    private static func applyDropboxPermission(_ link: String, permission: CloudLinkPermission) -> String {
        // Dropbox sharing links default to view-only.
        // dl=0 → preview page, dl=1 → direct download
        // For edit: need to change via API, but CLI gives view-only link
        switch permission {
        case .readOnly:
            return link.replacingOccurrences(of: "dl=1", with: "dl=0")
        case .allowEdit:
            // Dropbox edit links require API (not CLI) — append note
            log.info("[CloudLink] Dropbox edit permission requires web sharing settings")
            return link
        }
    }



    private static func openDropboxWeb(url: URL) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let relative = url.path
            .replacingOccurrences(of: "\(home)/Library/CloudStorage/Dropbox/", with: "")
            .replacingOccurrences(of: "\(home)/Dropbox/", with: "")
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
        let webURL = "https://www.dropbox.com/home/\(encoded)"
        openInBrowser(webURL)
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
    /// OneDrive — open web UI at the relative path
    private static func oneDriveLink(url: URL, permission: CloudLinkPermission) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let storagePath = "\(home)/Library/CloudStorage/"
        let relative = extractCloudRelativePath(from: url.path, storagePrefix: storagePath, providerPrefix: "OneDrive")
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
        let webURL = "https://onedrive.live.com/?view=0&id=root&qt=mru"
        openInBrowser(webURL)
        showNotification("OneDrive opened in browser. Navigate to '\(url.lastPathComponent)' and use Share → \(permission == .readOnly ? "View" : "Edit") link.")
        return false
    }



    // MARK: - Google Drive
    /// Google Drive — open web UI
    private static func googleDriveLink(url: URL, permission: CloudLinkPermission) -> Bool {
        openInBrowser("https://drive.google.com/drive/my-drive")
        showNotification("Google Drive opened in browser. Find '\(url.lastPathComponent)' and use Share → \(permission == .readOnly ? "Viewer" : "Editor").")
        return false
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

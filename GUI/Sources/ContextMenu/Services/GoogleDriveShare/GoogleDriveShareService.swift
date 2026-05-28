// GoogleDriveShareService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Uploads selected items to Google Drive Public folder and copies share links.

import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - GoogleDriveShareService

@MainActor
enum GoogleDriveShareService {

    // MARK: - Copy Share Link

    static func copyShareLink(for url: URL, permission: CloudLinkPermission) async -> Bool {
        let panel = ProgressPanel.shared
        panel.show(
            icon: "link.badge.plus",
            title: "Share+Link: \(url.lastPathComponent)",
            status: "Uploading to Google Drive…",
            operationKey: "google-drive-share"
        )
        panel.updateProgress(nil)
        panel.appendKeyValueLog("Source", value: url.path)
        do {
            log.info("[CloudLink] Google Drive upload start file='\(url.lastPathComponent)' permission=\(permission.rawValue)")
            panel.appendLog("Authenticating with Google Drive…")
            let token = try await GoogleDriveOAuthClient.accessToken()
            let client = GoogleDriveAPIClient(accessToken: token)
            panel.appendLog("Preparing your personal Google Drive public folder…")
            let publicFolder = try await client.ensurePublicFolder()
            panel.appendLog("Uploading item…")
            let uploaded = try await client.uploadEntry(at: url, parentID: publicFolder.id)
            panel.appendLog("Applying public \(permission.rawValue) permission…")
            try await client.applyPermission(fileID: uploaded.id, permission: permission)
            let metadata = try await client.fileMetadata(fileID: uploaded.id)
            let link = try shareLink(from: metadata)
            copyToClipboard(link)
            panel.appendLog("File uploaded to your personal Google Drive.")
            panel.appendKeyValueLog("File", value: url.lastPathComponent)
            panel.appendKeyValueLog("Path", value: url.path)
            panel.appendKeyValueLog("Public link", value: link)
            panel.appendLog("Public link copied to clipboard.")
            panel.finish(success: true, message: "Share+Link ready: link copied to clipboard", autoClose: false)
            panel.startAutoCloseTimerIfNeeded(seconds: 2)
            showNotification("Google Drive share link copied.")
            log.info("[CloudLink] Google Drive link copied fileID='\(uploaded.id)' link='\(link)'")
            return true
        } catch {
            panel.appendLog("❌ \(error.localizedDescription)")
            panel.finish(success: false, message: "Share+Link failed")
            showNotification("Google Drive share link failed: \(error.localizedDescription)")
            log.error("[CloudLink] Google Drive share failed: \(error.localizedDescription)")
            if case GoogleDriveError.missingClientSecret = error {
                log.error("[CloudLink] bundled or local Google desktop OAuth JSON is missing client_secret")
            }
            return false
        }
    }

    // MARK: - Share Link

    private static func shareLink(from file: GoogleDriveFile) throws -> String {
        if file.mimeType == "application/vnd.google-apps.folder" {
            return "https://drive.google.com/drive/folders/\(file.id)?usp=sharing"
        }
        if isInlineImage(file.mimeType) {
            return "https://lh3.googleusercontent.com/d/\(file.id)=s0"
        }
        if let webContentLink = file.webContentLink, webContentLink.isEmpty == false {
            return webContentLink
        }
        if let webViewLink = file.webViewLink, webViewLink.isEmpty == false {
            return webViewLink
        }
        return "https://drive.google.com/file/d/\(file.id)/view?usp=sharing"
    }

    // MARK: - Inline Image

    private static func isInlineImage(_ mimeType: String?) -> Bool {
        guard let mimeType,
              let type = UTType(mimeType: mimeType) else {
            return false
        }
        return type.conforms(to: .image)
    }

    // MARK: - Clipboard

    private static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Notification

    private static func showNotification(_ message: String) {
        log.info("[CloudLink] \(message)")
    }
}

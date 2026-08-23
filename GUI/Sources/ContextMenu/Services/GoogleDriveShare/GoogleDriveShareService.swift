// GoogleDriveShareService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Uploads selected items to Google Drive Public folder and copies share links.

import AppKit
import Foundation

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
            operationKey: "google-drive-share",
            cancelHandler: { CloudLinkService.cancelActiveShare() }
        )
        panel.updateProgress(nil)
        panel.appendKeyValueLog("Source", value: url.path)
        do {
            log.info("[CloudLink] Google Drive upload start file='\(url.lastPathComponent)' permission=\(permission.rawValue)")
            try Task.checkCancellation()
            panel.appendLog("Authenticating with Google Drive…")
            let token = try await GoogleDriveOAuthClient.accessToken()
            let client = GoogleDriveAPIClient(accessToken: token)
            panel.appendLog("Preparing your personal Google Drive public folder…")
            let publicFolder = try await client.ensurePublicFolder()
            panel.appendLog("Uploading item…")
            let uploaded = try await client.uploadEntry(at: url, parentID: publicFolder.id)
            try Task.checkCancellation()
            panel.appendLog("Applying public \(permission.rawValue) permission…")
            try await client.applyPermission(fileID: uploaded.id, permission: permission)
            let metadata = try await client.fileMetadata(fileID: uploaded.id)
            let link = shareLink(from: metadata)
            panel.appendLog("Creating MiMiNavi short link…")
            let copiedLink: String
            let copiedLinkLabel: String
            do {
                copiedLink = try await CloudLinkShortener.shorten(link)
                copiedLinkLabel = "Short link"
            } catch {
                copiedLink = link
                copiedLinkLabel = "Share link"
                panel.appendLog("⚠️ TinyURL could not create a short link; using the original Google Drive link.")
                log.warning("[CloudLink] TinyURL fallback host='\(URL(string: link)?.host ?? "unknown")': \(error.localizedDescription)")
            }
            copyToClipboard(copiedLink)
            panel.appendLog("File uploaded to your personal Google Drive.")
            panel.appendKeyValueLog("File", value: url.lastPathComponent)
            panel.appendKeyValueLog("Path", value: url.path)
            panel.appendKeyValueLog(copiedLinkLabel, value: copiedLink)
            panel.appendLog("Share link copied to clipboard.")
            panel.finish(success: true, message: "Share+Link ready: link copied to clipboard")
            FileOperationOutcomePresenter.success(
                .shareLink,
                resultURL: URL(string: copiedLink),
                displayName: "for \(url.lastPathComponent)"
            )
            log.info("[CloudLink] Google Drive link copied fileID='\(uploaded.id)' link='\(copiedLink)'")
            return true
        } catch is CancellationError {
            panel.finish(success: false, message: "Share+Link cancelled")
            FileOperationOutcomePresenter.cancelled(.shareLink)
            log.info("[CloudLink] Google Drive share cancelled")
            return false
        } catch {
            panel.appendLog("❌ \(error.localizedDescription)")
            panel.finish(success: false, message: "Share+Link failed")
            FileOperationOutcomePresenter.failure(.shareLink, error: error)
            log.error("[CloudLink] Google Drive share failed: \(error.localizedDescription)")
            if case GoogleDriveError.missingClientSecret = error {
                log.error("[CloudLink] bundled or local Google desktop OAuth JSON is missing client_secret")
            }
            return false
        }
    }

    // MARK: - Share Link

    private static func shareLink(from file: GoogleDriveFile) -> String {
        if file.mimeType == "application/vnd.google-apps.folder" {
            return "https://drive.google.com/drive/folders/\(file.id)?usp=sharing"
        }
        if let webViewLink = file.webViewLink, webViewLink.isEmpty == false {
            return webViewLink
        }
        return "https://drive.google.com/file/d/\(file.id)/view?usp=sharing"
    }

    // MARK: - Clipboard

    private static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

}

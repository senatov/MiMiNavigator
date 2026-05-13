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
        do {
            log.info("[CloudLink] Google Drive upload start file='\(url.lastPathComponent)' permission=\(permission.rawValue)")
            let token = try await GoogleDriveOAuthClient.accessToken()
            let client = GoogleDriveAPIClient(accessToken: token)
            let publicFolder = try await client.ensurePublicFolder()
            let uploaded = try await client.uploadEntry(at: url, parentID: publicFolder.id)
            try await client.applyPermission(fileID: uploaded.id, permission: permission)
            let metadata = try await client.fileMetadata(fileID: uploaded.id)
            let link = try shareLink(from: metadata)
            copyToClipboard(link)
            showNotification("Google Drive share link copied.")
            log.info("[CloudLink] Google Drive link copied fileID='\(uploaded.id)' link='\(link)'")
            return true
        } catch {
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

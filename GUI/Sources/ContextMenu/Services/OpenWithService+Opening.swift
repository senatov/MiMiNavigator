// OpenWithService+Opening.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Document opening and application picker for OpenWithService.

import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Open With File Actions
extension OpenWithService {
    // MARK: - Usage Recording
    func recordUsage(bundleID: String, ext: String, appURL: URL) {
        let normalizedExt = normalizedExtensionKey(for: ext)
        logInfo("recordUsage bundle='\(bundleID)' ext='\(normalizedExt)'")
        logDebug("recordUsage app='\(appURL.lastPathComponent)'")
        recordLRU(bundleID: bundleID, ext: ext, appURL: appURL)
    }
    // MARK: - Open File
    func openFile(_ fileURL: URL, with app: AppInfo) {
        logInfo("openFile file='\(fileURL.lastPathComponent)' app='\(app.name)'")
        recordLRU(bundleID: app.bundleIdentifier, ext: fileURL.pathExtension, appURL: app.url)
        if isRemoteFileURL(fileURL) {
            logInfo("remote file detected scheme='\(fileURL.scheme ?? "unknown")'")
            Task { await openRemoteFile(fileURL, with: app) }
            return
        }
        openLocalFile(fileURL, with: app)
    }
    private func openLocalFile(_ fileURL: URL, with app: AppInfo) {
        ExternalApplicationLauncher.shared.open(fileURL: fileURL, applicationURL: app.url, bundleIdentifier: app.bundleIdentifier)
    }
    private func openRemoteFile(_ fileURL: URL, with app: AppInfo) async {
        do {
            logInfo("downloading remote file path='\(fileURL.path)'")
            let localURL = try await remoteConnectionManager.downloadFile(remotePath: fileURL.path)
            openLocalFile(localURL, with: app)
            logInfo("remote download success local='\(localURL.path)'")
        } catch {
            logError("remote download failed: \(error.localizedDescription)")
        }
    }
    // MARK: - Default Application
    func openFileWithDefault(_ fileURL: URL) {
        logInfo("openFileWithDefault file='\(fileURL.lastPathComponent)'")
        workspace.open(fileURL)
    }
    // MARK: - Application Picker
    func showOpenWithPicker(for fileURL: URL) {
        logDebug("showOpenWithPicker file='\(fileURL.lastPathComponent)'")
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: Constants.applicationDirectory)
        panel.allowedContentTypes = [.application]
        panel.message = "Choose an application to open '\(fileURL.lastPathComponent)'"
        panel.prompt = "Open"
        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let appURL = panel.url else {
                self.logDebug("picker cancelled")
                return
            }
            self.openPickerSelection(appURL, fileURL: fileURL)
        }
    }
    private func openPickerSelection(_ appURL: URL, fileURL: URL) {
        logInfo("picker selected app='\(appURL.lastPathComponent)'")
        let icon = workspace.icon(forFile: appURL.path)
        icon.size = Constants.appIconSize
        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier ?? appURL.lastPathComponent
        let selectedApp = AppInfo(
            id: bundleIdentifier,
            name: fileManager.displayName(atPath: appURL.path),
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            url: appURL,
            isDefault: false
        )
        storeUserAssociation(bundleID: bundleIdentifier, ext: fileURL.pathExtension, appURL: appURL)
        openFile(fileURL, with: selectedApp)
    }
}

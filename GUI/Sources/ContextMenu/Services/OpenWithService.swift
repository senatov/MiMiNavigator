// OpenWithService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for "Open With" functionality - fetches available applications

import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Application Info
/// Represents an application that can open a file
struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    let url: URL
    let isDefault: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

// MARK: - Open With Service
/// Fetches applications capable of opening specific file types
@MainActor
final class OpenWithService {
    
    static let shared = OpenWithService()
    private let workspace = NSWorkspace.shared
    
    private init() {
        log.debug("\(#function) OpenWithService initialized")
    }
    
    // MARK: - Get Applications for File
    
    /// Returns list of applications that can open the given file
    func getApplications(for fileURL: URL) -> [AppInfo] {
        log.debug("\(#function) file='\(fileURL.lastPathComponent)' ext=\(fileURL.pathExtension)")
        
        guard UTType(filenameExtension: fileURL.pathExtension) != nil else {
            log.warning("\(#function) unknown UTType for ext='\(fileURL.pathExtension)', using fallback editors")
            return getAllEditors()
        }
        
        let defaultApp = workspace.urlForApplication(toOpen: fileURL)
        var apps: [AppInfo] = []
        var seenBundles = Set<String>()
        
        // Get apps from Launch Services
        if let appURLs = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?.takeRetainedValue() as? [URL] {
            log.debug("\(#function) LSCopyApplicationURLsForURL returned \(appURLs.count) apps")
            
            for appURL in appURLs {
                if let appInfo = makeAppInfo(from: appURL, isDefault: appURL == defaultApp) {
                    if !seenBundles.contains(appInfo.bundleIdentifier) {
                        seenBundles.insert(appInfo.bundleIdentifier)
                        apps.append(appInfo)
                    }
                }
            }
        } else {
            log.warning("\(#function) LSCopyApplicationURLsForURL returned nil")
        }
        
        // Sort: default app first, then alphabetically
        apps.sort { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        
        log.info("\(#function) found \(apps.count) apps for ext='\(fileURL.pathExtension)' default='\(defaultApp?.lastPathComponent ?? "none")'")
        return apps
    }
    
    // MARK: - Open File With Application
    
    /// Opens file with specified application
    func openFile(_ fileURL: URL, with app: AppInfo) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)' app='\(app.name)' bundle=\(app.bundleIdentifier)")
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        workspace.open([fileURL], withApplicationAt: app.url, configuration: config) { runningApp, error in
            if let error = error {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
            } else {
                log.debug("\(#function) SUCCESS opened with pid=\(runningApp?.processIdentifier ?? -1)")
            }
        }
    }
    
    /// Opens file with default application
    func openFileWithDefault(_ fileURL: URL) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)'")
        workspace.open(fileURL)
    }
    
    // MARK: - Show "Open With" System Dialog
    
    /// Shows system "Open With" picker (Choose Application...)
    func showOpenWithPicker(for fileURL: URL) {
        log.debug("\(#function) file='\(fileURL.lastPathComponent)'")
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.message = "Choose an application to open '\(fileURL.lastPathComponent)'"
        panel.prompt = "Open"
        
        panel.begin { response in
            if response == .OK, let appURL = panel.url {
                log.info("\(#function) user selected app='\(appURL.lastPathComponent)'")
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config)
            } else {
                log.debug("\(#function) user cancelled picker")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func makeAppInfo(from appURL: URL, isDefault: Bool) -> AppInfo? {
        guard let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return nil
        }
        
        let name = FileManager.default.displayName(atPath: appURL.path)
        let icon = workspace.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        
        return AppInfo(
            id: bundleIdentifier,
            name: name,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            url: appURL,
            isDefault: isDefault
        )
    }
    
    /// Fallback: common text editors for unknown file types
    private func getAllEditors() -> [AppInfo] {
        let editorPaths = [
            "/System/Applications/TextEdit.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/Sublime Text.app",
            "/Applications/BBEdit.app"
        ]
        
        let editors = editorPaths.compactMap { path -> AppInfo? in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return makeAppInfo(from: url, isDefault: false)
        }
        
        log.debug("\(#function) returning \(editors.count) fallback editors")
        return editors
    }
}

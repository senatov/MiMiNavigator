// SmartIconService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Smart icon resolution with fallback chain.
//              Extracted from FileRowView — pure service logic, no SwiftUI.
//              Priority: Encrypted archive → Special types → Magic bytes →
//              App icon → UTType icon → Generic.

import AppKit
import FileModelKit
import UniformTypeIdentifiers

// MARK: - SmartIconService
enum SmartIconService {

    // MARK: - Icon cache
    private static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    // MARK: - Primary API: icon for CustomFile
    @MainActor
    static func icon(for file: CustomFile) -> NSImage {
        let extKey = (file.urlValue.pathExtension.lowercased()
            + (file.isDirectory ? "_dir" : "")
            + (file.isSymbolicLink ? "_sym" : "")) as NSString
        if let cached = iconCache.object(forKey: extKey) {
            return cached
        }
        let url = file.urlValue
        let workspace = NSWorkspace.shared
        let iconSize = NSSize(width: 128, height: 128)
        if !FileManager.default.fileExists(atPath: url.path) {
            return remoteIcon(for: file, size: iconSize)
        }
        if file.isSymbolicLink {
            return AliasIconComposer.compose(symlinkURL: url, size: iconSize)
        }
        if file.isDirectory {
            let icon = workspace.icon(forFile: url.path)
            icon.size = iconSize
            return icon
        }
        let pathExtension = url.pathExtension.lowercased()
        if file.isArchiveFile && EncryptedArchiveCheck.isEncrypted(url: url) {
            return encryptedArchiveIcon(size: iconSize)
        }
        if pathExtension.isEmpty {
            let detected = FileMagicDetector.detect(url: url)
            if detected != .unknown {
                return sfSymbolIcon(detected.sfSymbol, size: iconSize)
            }
        }
        if let specialIcon = specialTypeIcon(for: pathExtension) {
            specialIcon.size = iconSize
            return specialIcon
        }
        if let appURL = workspace.urlForApplication(toOpen: url),
           !isGenericHandler(appURL: appURL, forExtension: pathExtension) {
            let appIcon = workspace.icon(forFile: appURL.path)
            appIcon.size = iconSize
            return appIcon
        }
        if !pathExtension.isEmpty,
           let uttype = UTType(filenameExtension: pathExtension) {
            let uttypeIcon = workspace.icon(for: uttype)
            uttypeIcon.size = iconSize
            return uttypeIcon
        }
        log.debug("[SmartIcon] fallback for '\(url.lastPathComponent)' ext='\(url.pathExtension)'")
        let icon = workspace.icon(forFile: url.path)
        icon.size = iconSize
        iconCache.setObject(icon, forKey: extKey)
        return icon
    }

    // MARK: - URL-based API (for FindFilesResultsView and other callers)
    @MainActor
    static func icon(for url: URL, size: NSSize = NSSize(width: 128, height: 128)) -> NSImage {
        let workspace = NSWorkspace.shared
        guard FileManager.default.fileExists(atPath: url.path) else {
            let ext = url.pathExtension.lowercased()
            if !ext.isEmpty, let uttype = UTType(filenameExtension: ext) {
                let icon = workspace.icon(for: uttype)
                icon.size = size
                return icon
            }
            let icon = workspace.icon(for: .data)
            icon.size = size
            return icon
        }
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            return AliasIconComposer.compose(symlinkURL: url, size: size)
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            let icon = workspace.icon(forFile: url.path)
            icon.size = size
            return icon
        }
        let ext = url.pathExtension.lowercased()
        let archiveExts: Set<String> = [
            "zip", "7z", "rar", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "dmg", "pkg", "jar", "apk",
        ]
        if archiveExts.contains(ext) && EncryptedArchiveCheck.isEncrypted(url: url) {
            return encryptedArchiveIcon(size: size)
        }
        if let special = specialTypeIcon(for: ext) {
            special.size = size
            return special
        }
        if let appURL = workspace.urlForApplication(toOpen: url),
           !isGenericHandler(appURL: appURL, forExtension: ext) {
            let icon = workspace.icon(forFile: appURL.path)
            icon.size = size
            return icon
        }
        if !ext.isEmpty, let uttype = UTType(filenameExtension: ext) {
            let icon = workspace.icon(for: uttype)
            icon.size = size
            return icon
        }
        let icon = workspace.icon(forFile: url.path)
        icon.size = size
        return icon
    }

    // MARK: - Remote file icon
    private static func remoteIcon(for file: CustomFile, size: NSSize) -> NSImage {
        if file.isDirectory || file.isSymbolicDirectory {
            let icon = NSWorkspace.shared.icon(for: .folder)
            icon.size = size
            return icon
        }
        let ext = file.fileExtension.lowercased()
        if !ext.isEmpty, let uttype = UTType(filenameExtension: ext) {
            let icon = NSWorkspace.shared.icon(for: uttype)
            icon.size = size
            return icon
        }
        let icon = NSWorkspace.shared.icon(for: .data)
        icon.size = size
        return icon
    }

    // MARK: - Special type icons (fonts, system files, databases)
    private static func specialTypeIcon(for ext: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        let fontExtensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
        if fontExtensions.contains(ext) {
            if let fontBookURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.FontBook") {
                return workspace.icon(forFile: fontBookURL.path)
            }
            return workspace.icon(for: .font)
        }
        let configExtensions = ["plist", "entitlements", "xcconfig"]
        if configExtensions.contains(ext) {
            if let uttype = UTType(filenameExtension: ext) {
                return workspace.icon(for: uttype)
            }
        }
        let dbExtensions = ["db", "sqlite", "sqlite3", "realm"]
        if dbExtensions.contains(ext) {
            return workspace.icon(for: .database)
        }
        return nil
    }

    // MARK: - Encrypted archive icon
    static func encryptedArchiveIcon(size: NSSize) -> NSImage {
        let symbolName = "key.2.on.ring"
        let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.7, weight: .medium)
            .applying(.init(paletteColors: [.systemBrown, .systemOrange, .darkGray]))
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Encrypted archive") {
            let configured = img.withSymbolConfiguration(config) ?? img
            configured.size = size
            return configured
        }
        let fallback = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Encrypted") ?? NSImage()
        fallback.size = size
        return fallback
    }

    // MARK: - SF Symbol to NSImage
    private static func sfSymbolIcon(_ symbolName: String, size: NSSize) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.6, weight: .regular)
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let configured = img.withSymbolConfiguration(config) ?? img
            configured.size = size
            return configured
        }
        let fallback = NSImage(systemSymbolName: "doc.questionmark", accessibilityDescription: nil) ?? NSImage()
        fallback.size = size
        return fallback
    }

    // MARK: - Generic handler check
    static func isGenericHandler(appURL: URL, forExtension ext: String) -> Bool {
        let genericBundleIDs = [
            "org.libreoffice.script",
            "com.apple.TextEdit",
            "com.apple.dt.Xcode",
        ]
        if let bundle = Bundle(url: appURL),
           let bundleID = bundle.bundleIdentifier {
            let fontExtensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
            if fontExtensions.contains(ext) && genericBundleIDs.contains(bundleID) {
                return true
            }
        }
        return false
    }
}

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
    nonisolated(unsafe) private static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 192
        cache.totalCostLimit = 12 * 1_024 * 1_024
        return cache
    }()

    // MARK: - Clear Memory Cache
    @MainActor
    static func clearMemoryCache() {
        iconCache.removeAllObjects()
    }

    // MARK: - Primary API: icon for CustomFile
    @MainActor
    static func icon(
        for file: CustomFile,
        content: IconContentInspection = .init(),
        size: CGFloat = SystemIconNormalizer.logicalSize.width
    ) -> NSImage {
        let iconSize = NSSize(width: size, height: size)
        let extKey =
            (
                file.isDirectory
                    ? "dir:\(file.urlValue.standardizedFileURL.path)"
                    : file.urlValue.pathExtension.lowercased() + (file.isSymbolicLink ? "_sym" : "")
            ) as NSString
        let sizedKey = "\(extKey):\(Int((size * 10).rounded()))" as NSString
        if content.kind == .unknown, !content.isEncrypted, let cached = iconCache.object(forKey: sizedKey) {
            return cached
        }
        let url = file.urlValue
        let workspace = NSWorkspace.shared
        if !FileManager.default.fileExists(atPath: url.path) {
            let icon = remoteIcon(for: file, size: iconSize)
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        if file.isSymbolicLink {
            return AliasIconComposer.compose(symlinkURL: url, size: iconSize)
        }
        if file.isDirectory {
            // OS-hidden dirs (~/Library etc.) — eye.slash badge
            if file.isOSHiddenOnly {
                let icon = OSHiddenIconComposer.compose(url: url, size: iconSize)
                iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
                return icon
            }
            let icon = workspace.icon(forFile: url.path)
            icon.size = iconSize
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        let pathExtension = url.pathExtension.lowercased()
        if file.isArchiveFile && content.isEncrypted {
            return archiveIcon(for: pathExtension, isEncrypted: true, size: iconSize, fallbackURL: url)
        }
        if file.isArchiveFile {
            let icon = archiveIcon(for: pathExtension, isEncrypted: false, size: iconSize, fallbackURL: url)
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        if pathExtension.isEmpty {
            let detected = content.kind
            if detected != .unknown {
                return sfSymbolIcon(detected.sfSymbol, size: iconSize)
            }
        }
        if let specialIcon = specialTypeIcon(for: pathExtension) {
            let icon = SystemIconNormalizer.normalize(specialIcon, size: iconSize)
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        if let appURL = workspace.urlForApplication(toOpen: url),
           !isGenericHandler(appURL: appURL, forExtension: pathExtension) {
            let appIcon = workspace.icon(forFile: appURL.path)
            let icon = SystemIconNormalizer.normalize(appIcon, size: iconSize)
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        if !pathExtension.isEmpty,
           let uttype = UTType(filenameExtension: pathExtension) {
            let uttypeIcon = workspace.icon(for: uttype)
            let icon = SystemIconNormalizer.normalize(uttypeIcon, size: iconSize)
            iconCache.setObject(icon, forKey: sizedKey, cost: iconCost(for: iconSize))
            return icon
        }
        log.debug("[SmartIcon] fallback for '\(url.lastPathComponent)' ext='\(url.pathExtension)'")
        let icon = workspace.icon(forFile: url.path)
        let normalized = SystemIconNormalizer.normalize(icon, size: iconSize)
        iconCache.setObject(normalized, forKey: sizedKey, cost: iconCost(for: iconSize))
        return normalized
    }

    // MARK: - Icon Cost
    private static func iconCost(for size: NSSize) -> Int {
        Int(size.width * size.height * 16)
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
        if ArchiveExtensions.isArchive(ext) {
            return archiveIcon(for: ext, isEncrypted: false, size: size, fallbackURL: url)
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
    @MainActor
    private static func remoteIcon(for file: CustomFile, size: NSSize) -> NSImage {
        if file.isDirectory || file.isSymbolicDirectory {
            let icon = NSWorkspace.shared.icon(for: .folder)
            icon.size = size
            return icon
        }
        let ext = file.fileExtension.lowercased()
        if !ext.isEmpty, let uttype = UTType(filenameExtension: ext) {
            let icon = NSWorkspace.shared.icon(for: uttype)
            return SystemIconNormalizer.normalize(icon, size: size)
        }
        let icon = NSWorkspace.shared.icon(for: .data)
        return SystemIconNormalizer.normalize(icon, size: size)
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

    // MARK: - Archive Icon
    static func archiveIconAssetName(for ext: String, isEncrypted: Bool) -> String {
        if isEncrypted { return "ArchiveEncrypted" }
        let normalized = ext.lowercased()
        if normalized == "dmg" { return "DiskImageInstaller" }
        if normalized == "zip" { return "ArchiveSystem" }
        let clampFormats: Set<String> = ["7z", "rar", "cab", "arj", "lha", "lzh", "ace", "sit", "sitx"]
        if clampFormats.contains(normalized) { return "ArchiveClamp" }
        let systemFormats: Set<String> = [
            "tar", "cpio", "rpm", "deb", "pkg", "xar", "jar", "war", "ear", "aar", "apk",
            "iso", "img", "vhd", "vmdk", "wim", "swm", "squashfs", "cramfs",
        ]
        if systemFormats.contains(normalized) { return "ArchiveSystem" }
        return "ArchiveZip"
    }
    @MainActor
    private static func archiveIcon(
        for ext: String,
        isEncrypted: Bool,
        size: NSSize,
        fallbackURL: URL
    ) -> NSImage {
        let assetName = archiveIconAssetName(for: ext, isEncrypted: isEncrypted)
        if assetName == "DiskImageInstaller" {
            return sfSymbolIcon("basketball.fill", size: size)
        }
        let asset = NSImage(named: assetName)?.copy() as? NSImage
        if let asset {
            return SystemIconNormalizer.normalize(asset, size: size)
        }
        let icon = asset ?? NSWorkspace.shared.icon(forFile: fallbackURL.path)
        icon.size = size
        return icon
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

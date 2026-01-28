// FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File row content view (icon + name)
struct FileRowView: View {
    let file: CustomFile
    let isSelected: Bool
    let isActivePanel: Bool

    // MARK: - View Body
    var body: some View {
        baseContent()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, RowDesignTokens.grid / 2)
            .padding(.horizontal, RowDesignTokens.grid)
            .contentShape(Rectangle())
    }

    // MARK: - Text color based on selection state (Finder style - all black/white)
    private var nameColor: Color {
        if isSelected && isActivePanel {
            return .white
        }
        return .primary
    }

    // MARK: - Base content for a single file row (icon + name)
    private func baseContent() -> some View {
        HStack(spacing: 8) {
            // File icon
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: getSmartIcon(for: file))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                
                // Symlink badge overlay (smaller for Finder-style icons)
                if file.isSymbolicLink {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(1.5)
                        .background(
                            Circle()
                                .fill(Color.orange)
                                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0.3, y: 0.3)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .allowsHitTesting(false)
            .layoutPriority(1)
            
            // File name - Finder style (system font, truncates in middle)
            Text(file.nameStr)
                .font(.system(size: 13))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(0)
        }
    }
    
    // MARK: - Smart icon selection with fallback chain
    /// Priority: Special types → App icon → UTType icon → Generic file icon
    private func getSmartIcon(for file: CustomFile) -> NSImage {
        let url = file.urlValue
        let workspace = NSWorkspace.shared
        let iconSize = NSSize(width: 128, height: 128)
        
        // For directories - use system folder icon
        if file.isDirectory || file.isSymbolicDirectory {
            let icon = workspace.icon(forFile: url.path)
            icon.size = iconSize
            return icon
        }
        
        let pathExtension = url.pathExtension.lowercased()
        
        // 0. Check for special file types that need specific handling
        if let specialIcon = getSpecialTypeIcon(for: pathExtension) {
            specialIcon.size = iconSize
            return specialIcon
        }
        
        // 1. Try to get default app icon (most colorful option)
        if let appURL = workspace.urlForApplication(toOpen: url) {
            // Skip if app is a generic handler (like LibreOffice for fonts)
            if !isGenericHandler(appURL: appURL, forExtension: pathExtension) {
                let appIcon = workspace.icon(forFile: appURL.path)
                appIcon.size = iconSize
                return appIcon
            }
        }
        
        // 2. Try by UTType - find appropriate app
        if !pathExtension.isEmpty,
           let uttype = UTType(filenameExtension: pathExtension) {
            
            // Get system icon for this UTType (often better than app icon)
            let uttypeIcon = workspace.icon(for: uttype)
            uttypeIcon.size = iconSize
            return uttypeIcon
        }
        
        // 3. Final fallback: standard file icon
        let icon = workspace.icon(forFile: url.path)
        icon.size = iconSize
        return icon
    }
    
    // MARK: - Special type icons (fonts, system files, etc.)
    /// Returns appropriate icon for file types that shouldn't use app icons
    private func getSpecialTypeIcon(for ext: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        
        // Font files - use Font Book icon or UTType
        let fontExtensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
        if fontExtensions.contains(ext) {
            // Try Font Book app icon
            if let fontBookURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.FontBook") {
                return workspace.icon(forFile: fontBookURL.path)
            }
            // Fallback to UTType.font icon
            return workspace.icon(for: .font)
        }
        
        // System/config files
        let configExtensions = ["plist", "entitlements", "xcconfig"]
        if configExtensions.contains(ext) {
            if let uttype = UTType(filenameExtension: ext) {
                return workspace.icon(for: uttype)
            }
        }
        
        // Database files
        let dbExtensions = ["db", "sqlite", "sqlite3", "realm"]
        if dbExtensions.contains(ext) {
            return workspace.icon(for: .database)
        }
        
        return nil
    }
    
    // MARK: - Check if app is a generic handler (not the best icon source)
    /// Some apps register for many file types but their icon isn't representative
    private func isGenericHandler(appURL: URL, forExtension ext: String) -> Bool {
        let genericBundleIDs = [
            "org.libreoffice.script",
            "com.apple.TextEdit",
            "com.apple.dt.Xcode"  // Xcode handles too many types
        ]
        
        if let bundle = Bundle(url: appURL),
           let bundleID = bundle.bundleIdentifier {
            // Font files should not use LibreOffice or TextEdit icons
            let fontExtensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
            if fontExtensions.contains(ext) && genericBundleIDs.contains(bundleID) {
                return true
            }
        }
        
        return false
    }
}

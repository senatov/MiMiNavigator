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
    var isMarked: Bool = false  // Total Commander style marking

    // MARK: - View Body
    var body: some View {
        baseContent()
            .padding(.vertical, DesignTokens.grid / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    // MARK: - Text color based on selection, mark, and hidden state
    /// macOS Finder style:
    /// - Selected + active panel → white
    /// - Marked → accent color
    /// - Hidden → tertiary label (dimmed gray, like Finder)
    /// - Normal → primary
    /// Whether this row is the ".." parent directory navigation entry
    private var isParentEntry: Bool {
        ParentDirectoryEntry.isParentEntry(file)
    }

    private var nameColor: Color {
        if isSelected && isActivePanel {
            return .white
        }
        if isMarked {
            // Total Commander style: dark red for marked files
            return Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1))
        }
        // Dark blue for ".." parent entry
        if isParentEntry {
            return Color(#colorLiteral(red: 0.2, green: 0.2, blue: 0.7, alpha: 1))
        }
        if file.isHidden {
            return Color(#colorLiteral(red: 0.3767382812, green: 0.3767382812, blue: 0.3767382812, alpha: 1))  // Brighter bluish gray
        }
        return .primary
    }

    // MARK: - Font weight: bold for marked files (Total Commander style)
    private var nameWeight: Font.Weight {
        isMarked ? .semibold : .regular
    }

    // MARK: - Font size: slightly larger for marked files
    private var nameFontSize: CGFloat {
        isMarked ? 14 : 13
    }

    // MARK: - Icon opacity (Finder-style dimming for hidden files)
    private var iconOpacity: Double {
        if isSelected && isActivePanel { return 1.0 }
        return file.isHidden ? 0.45 : 1.0
    }

    // MARK: - Base content for a single file row (icon + name)
    private func baseContent() -> some View {
        HStack(spacing: 8) {
            if isParentEntry {
                // Special icon for "..." parent directory entry — accented, larger
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.Row.iconSize + 2, height: DesignTokens.Row.iconSize + 2)
                    .foregroundStyle(isSelected && isActivePanel ? .white : Color(#colorLiteral(red: 0.15, green: 0.15, blue: 0.65, alpha: 1)))
                    .allowsHitTesting(false)
                    .layoutPriority(1)

                Text("...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .layoutPriority(0)
            } else {
                // Normal file icon (dimmed for hidden files, like Finder)
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: getSmartIcon(for: file))
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: DesignTokens.Row.iconSize, height: DesignTokens.Row.iconSize)
                        .opacity(iconOpacity)

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

                // File name - with mark indicator
                HStack(spacing: 4) {
                    if isMarked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(#colorLiteral(red: 0.7, green: 0.0, blue: 0.0, alpha: 1)))
                    }

                    Text(file.nameStr)
                        .font(.system(size: nameFontSize, weight: nameWeight))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(0)
            }
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
            let uttype = UTType(filenameExtension: pathExtension)
        {

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
            "com.apple.dt.Xcode",  // Xcode handles too many types
        ]

        if let bundle = Bundle(url: appURL),
            let bundleID = bundle.bundleIdentifier
        {
            // Font files should not use LibreOffice or TextEdit icons
            let fontExtensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
            if fontExtensions.contains(ext) && genericBundleIDs.contains(bundleID) {
                return true
            }
        }

        return false
    }
}

    // FileRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.08.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import AppKit
    import FileModelKit
    import SwiftUI
    import UniformTypeIdentifiers

    // MARK: - File row content view (icon + name)
    struct FileRowView: View {
        let file: CustomFile
        let isSelected: Bool
        let isActivePanel: Bool
        var isMarked: Bool = false  // Total Commander style marking
        private let colorStore = ColorThemeStore.shared

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
            if isMarked {
                return colorStore.activeTheme.markedFileColor
            }
            if isParentEntry {
                return colorStore.activeTheme.parentEntryColor
            }
            if file.isHidden {
                return colorStore.activeTheme.hiddenFileColor
            }
            if file.isSymbolicLink {
                return colorStore.activeTheme.symlinkColor
            }
            if file.isDirectory {
                return colorStore.activeTheme.dirNameColor
            }
            return colorStore.activeTheme.fileNameColor
        }

        // MARK: - Font weight: same for marked and normal (no bold)
        private static var nameWeight: Font.Weight {
            .regular
        }

        // MARK: - Font size: same for marked and normal
        private static var nameFontSize: CGFloat {
            13
        }

        // MARK: - Icon opacity (Finder-style dimming for hidden files)
        private var iconOpacity: Double {
            return file.isHidden ? 0.45 : 1.0
        }

        // MARK: - Base content for a single file row (icon + name)
        private func baseContent() -> some View {
            // Parent directory entry: render as a simple navigation control
            if isParentEntry {
                return AnyView(
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: DesignTokens.Row.iconSize + 2, height: DesignTokens.Row.iconSize + 2)
                            .foregroundStyle(colorStore.activeTheme.parentEntryColor)

                        Text("...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(nameColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                )
            }

            // Normal file row
            return AnyView(
                HStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncSmartIconView(file: file)
                            .frame(width: DesignTokens.Row.iconSize, height: DesignTokens.Row.iconSize)
                            .opacity(iconOpacity)
                    }
                    .allowsHitTesting(false)
                    .layoutPriority(1)

                    HStack(spacing: 4) {
                        if isMarked {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(colorStore.activeTheme.markedFileColor)
                        }

                        Text(file.nameStr)
                            .font(.system(size: Self.nameFontSize, weight: Self.nameWeight))
                            .foregroundStyle(nameColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .layoutPriority(0)
                }
            )
        }

        // MARK: - Smart icon selection with fallback chain
        /// Priority: Encrypted archive → Special types → Magic bytes (no ext) → App icon → UTType icon → Generic
        @MainActor static func getSmartIcon(for file: CustomFile) -> NSImage {
            // Fast icon cache to avoid thousands of NSWorkspace / UTType lookups
            let extKey =
                (file.urlValue.pathExtension.lowercased() + (file.isDirectory ? "_dir" : "") + (file.isSymbolicLink ? "_sym" : ""))
                as NSString
            if let cached = Self.iconCache.object(forKey: extKey) {
                return cached
            }

            let url = file.urlValue
            let workspace = NSWorkspace.shared
            let iconSize = NSSize(width: 128, height: 128)

            // Remote files — use generic icons by type (no local path to query)
            if !FileManager.default.fileExists(atPath: url.path) {
                return remoteIcon(for: file, size: iconSize)
            }

            // Symlinks (aliases) — NSWorkspace adds the Finder arrow badge automatically
            if file.isSymbolicLink {
                return AliasIconComposer.compose(symlinkURL: url, size: iconSize)
            }
            // For directories — use system folder icon
            if file.isDirectory {
                let icon = workspace.icon(forFile: url.path)
                icon.size = iconSize
                return icon
            }

            let pathExtension = url.pathExtension.lowercased()

            // Encrypted archive detection (ZIP: fast 8-byte read, cached)
            if file.isArchiveFile && EncryptedArchiveCheck.isEncrypted(url: url) {
                return Self.encryptedArchiveIcon(size: iconSize)
            }

            // Extensionless files — detect type by magic bytes (16-byte read, cached)
            if pathExtension.isEmpty {
                let detected = FileMagicDetector.detect(url: url)
                if detected != .unknown {
                    return Self.sfSymbolIcon(detected.sfSymbol, size: iconSize)
                }
            }

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
            log.debug("[FileRowView] icon fallback for '\(url.lastPathComponent)' ext='\(url.pathExtension)'")
            let icon = workspace.icon(forFile: url.path)
            icon.size = iconSize
            Self.iconCache.setObject(icon, forKey: extKey)
            return icon
        }

        // MARK: - Remote file icon (no local path available)
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

        // MARK: - Special type icons (fonts, system files, etc.)
        /// Returns appropriate icon for file types that shouldn't use app icons
        private static func getSpecialTypeIcon(for ext: String) -> NSImage? {
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

        // MARK: - Encrypted Archive Icon
        /// Generates an NSImage from SF Symbol "lock.doc" for encrypted archives
        private static func encryptedArchiveIcon(size: NSSize) -> NSImage {
            let symbolName = "key.2.on.ring"
            let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.7, weight: .medium)
                .applying(.init(paletteColors: [.systemBrown, .systemOrange, .darkGray]))
            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Encrypted archive") {
                let configured = img.withSymbolConfiguration(config) ?? img
                configured.size = size
                return configured
            }
            // Fallback: key icon
            let fallback = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Encrypted") ?? NSImage()
            fallback.size = size
            return fallback
        }
        // MARK: - URL-based icon (for FindFilesResultsView and other non-CustomFile callers)
        @MainActor static func getSmartIcon(for url: URL, size: NSSize = NSSize(width: 128, height: 128)) -> NSImage {
            let workspace = NSWorkspace.shared
            guard FileManager.default.fileExists(atPath: url.path) else {
                // Remote / archive-internal — use UTType icon
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
            // Symlink
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                return AliasIconComposer.compose(symlinkURL: url, size: size)
            }
            // Directory
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
            if let special = getSpecialTypeIcon(for: ext) {
                special.size = size
                return special
            }
            if let appURL = workspace.urlForApplication(toOpen: url),
                !isGenericHandler(appURL: appURL, forExtension: ext)
            {
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

        // MARK: - SF Symbol to NSImage
        /// Renders an SF Symbol name as an NSImage at given size
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
        // MARK: - Check if app is a generic handler (not the best icon source)
        /// Some apps register for many file types but their icon isn't representative
        private static func isGenericHandler(appURL: URL, forExtension ext: String) -> Bool {
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
        // MARK: - Async icon loader (prevents UI stalls in large directories)
        struct AsyncSmartIconView: View {

            let file: CustomFile

            @State private var icon: NSImage?

            var body: some View {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "doc")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .task(id: file.urlValue.path) {
                    await loadIcon()
                }
            }

            private func loadIcon() async {
                let result =
                    await Task.detached(priority: .utility) {
                        await FileRowView.getSmartIcon(for: file)
                    }
                    .value

                await MainActor.run {
                    self.icon = result
                }
            }
        }

        // MARK: - Icon cache (massively reduces icon generation for large folders)
        private static let iconCache: NSCache<NSString, NSImage> = {
            let cache = NSCache<NSString, NSImage>()
            cache.countLimit = 256
            return cache
        }()
    }

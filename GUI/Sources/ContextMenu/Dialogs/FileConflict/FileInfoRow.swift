    // FileInfoRow.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 23.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Row component displaying file metadata with icon

    import SwiftUI
    import AppKit

    // MARK: - File Info Row
    /// Displays file information including icon, path, name, date and size
    struct FileInfoRow: View {
        let title: String
        let url: URL
        let name: String
        let size: Int64
        let date: Date?
        
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleText
            HStack(alignment: .top, spacing: 10) {
                fileIcon
                fileDetails
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
    }
        
        // MARK: - Private Views
        private var fileIcon: some View {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadius(4)
        }
        
        private var fileDetails: some View {
            VStack(alignment: .leading, spacing: 3) {
                nameText
                pathText
                dateText
                sizeText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        private var titleText: some View {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
        }
        
        private var nameText: some View {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }

        private var pathText: some View {
            Text(parentPath)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        
        private var dateText: some View {
            Text(formattedDate)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        }

        private var cardBorder: some View {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        }
        
        private var sizeText: some View {
            Text(formattedSize)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed Properties
    private extension FileInfoRow {
        var icon: NSImage {
            // Cache icons by file extension to avoid thousands of NSWorkspace icon lookups
            let ext = url.pathExtension.lowercased() as NSString
            if let cached = Self.iconCache.object(forKey: ext) {
                return cached
            }

            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Self.iconCache.setObject(icon, forKey: ext)
            return icon
        }
        
        var parentPath: String {
            url.deletingLastPathComponent().path
        }
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        var formattedDate: String {
            guard let date = date else { return "" }
            return Self.dateFormatter.string(from: date)
        }
        
        /// Cache icons by file extension (massively reduces NSWorkspace calls in large directories)
        static let iconCache: NSCache<NSString, NSImage> = {
            let cache = NSCache<NSString, NSImage>()
            cache.countLimit = 128
            return cache
        }()

        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d. MMMM yyyy 'at' HH:mm:ss"
            return formatter
        }()
    }

    // MARK: - Preview
    #Preview {
        FileInfoRow(
            title: "Copying",
            url: URL(fileURLWithPath: "/Users/senat/Downloads/test.mp4"),
            name: "test.mp4",
            size: 1_234_567,
            date: Date()
        )
        .padding()
        .frame(width: 400)
    }

// FileConflictDialog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Conflict Resolution
enum ConflictResolution: Equatable {
    case skip
    case keepBoth
    case replace
    case stop
}

// MARK: - File Conflict Info
struct FileConflictInfo {
    let sourceURL: URL
    let targetURL: URL
    let sourceName: String
    let targetName: String
    let sourceSize: Int64
    let targetSize: Int64
    let sourceDate: Date?
    let targetDate: Date?
    
    init(source: URL, target: URL) {
        self.sourceURL = source
        self.targetURL = target
        self.sourceName = source.lastPathComponent
        self.targetName = target.lastPathComponent
        
        let fm = FileManager.default
        let sourceAttrs = try? fm.attributesOfItem(atPath: source.path)
        let targetAttrs = try? fm.attributesOfItem(atPath: target.path)
        
        self.sourceSize = (sourceAttrs?[.size] as? NSNumber)?.int64Value ?? 0
        self.targetSize = (targetAttrs?[.size] as? NSNumber)?.int64Value ?? 0
        self.sourceDate = sourceAttrs?[.modificationDate] as? Date
        self.targetDate = targetAttrs?[.modificationDate] as? Date
    }
}

// MARK: - File Conflict Dialog (HIG Style)
struct FileConflictDialog: View {
    let conflict: FileConflictInfo
    let onResolve: (ConflictResolution) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("[ File Name ] Conflict")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Content
            VStack(spacing: 16) {
                // Source file (Copying)
                FileInfoRow(
                    title: "Copying",
                    url: conflict.sourceURL,
                    name: conflict.sourceName,
                    size: conflict.sourceSize,
                    date: conflict.sourceDate
                )
                
                Divider()
                    .padding(.horizontal)
                
                // Target file (Existing)
                FileInfoRow(
                    title: "Existing Target",
                    url: conflict.targetURL,
                    name: conflict.targetName,
                    size: conflict.targetSize,
                    date: conflict.targetDate
                )
            }
            .padding(16)
            
            Divider()
            
            // Buttons
            HStack(spacing: 8) {
                Spacer()
                
                ConflictButton(title: "Skip", action: { onResolve(.skip) })
                
                ConflictButton(title: "Keep Both", isPrimary: true, action: { onResolve(.keepBoth) })
                
                ConflictButton(title: "Stop", action: { onResolve(.stop) })
                
                ConflictButton(title: "Replace", action: { onResolve(.replace) })
            }
            .padding(12)
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - File Info Row
private struct FileInfoRow: View {
    let title: String
    let url: URL
    let name: String
    let size: Int64
    let date: Date?
    
    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    private var parentPath: String {
        let parent = url.deletingLastPathComponent().path
        // Highlight last component in orange
        return parent
    }
    
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private var formattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMMM yyyy 'at' HH:mm:ss"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // File preview/icon
            Image(nsImage: icon)
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadius(4)
            
            // File info
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                
                // Path with highlighted folder
                PathWithHighlight(path: parentPath)
                
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Text(formattedSize)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Path with Highlighted Folder
private struct PathWithHighlight: View {
    let path: String
    
    var body: some View {
        let components = path.split(separator: "/").map(String.init)
        
        HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Text("/")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Text(component)
                    .font(.system(size: 10))
                    .foregroundStyle(index == components.count - 1 ? Color.orange : .secondary)
            }
        }
    }
}

// MARK: - Conflict Button
private struct ConflictButton: View {
    let title: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isPrimary ? .medium : .regular))
                .foregroundStyle(isPrimary ? .white : .primary)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isPrimary 
                            ? (isHovering ? Color.accentColor.opacity(0.9) : Color.accentColor)
                            : (isHovering ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isPrimary ? Color.clear : Color.gray.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Preview
#Preview {
    FileConflictDialog(
        conflict: FileConflictInfo(
            source: URL(fileURLWithPath: "/Users/senat/Downloads/test.mp4"),
            target: URL(fileURLWithPath: "/private/tmp/test.mp4")
        ),
        onResolve: { _ in }
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

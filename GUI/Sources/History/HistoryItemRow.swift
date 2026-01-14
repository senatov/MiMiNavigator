// HistoryItemRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - HistoryItemRow
struct HistoryItemRow: View {
    let path: String
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Path button
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                    
                    Text(truncatedPath)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .help(path)  // Full path on hover
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Delete button (visible on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Remove from history")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Path truncation
    private var truncatedPath: String {
        let components = (path as NSString).pathComponents
        guard components.count > 3 else { return path }
        
        // Show: /first/.../second-to-last/last
        let first = components[0]
        let secondToLast = components[components.count - 2]
        let last = components[components.count - 1]
        
        return "\(first)/…/\(secondToLast)/\(last)"
    }
}

// HistoryItemRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.

import SwiftUI

// MARK: - HistoryItemRow
struct HistoryItemRow: View {
    let path: String
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    private let maxDisplayWidth: CGFloat = 170
    
    var body: some View {
        HStack(spacing: 8) {
            // Path button
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                    
                    Text(truncatedPath)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: maxDisplayWidth, alignment: .leading)
                        .help(path)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Delete button - always visible, red X
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(isHovered ? Color.red : Color.gray)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Remove from history")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Path truncation (macOS style: middle truncation)
    private var truncatedPath: String {
        abbreviatePath(path, maxLength: 40)
    }
    
    // MARK: - Abbreviate path macOS style
    private func abbreviatePath(_ path: String, maxLength: Int) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var displayPath = path
        if displayPath.hasPrefix(homePath) {
            displayPath = "~" + displayPath.dropFirst(homePath.count)
        }
        
        guard displayPath.count > maxLength else { return displayPath }
        
        let components = (displayPath as NSString).pathComponents
        guard components.count > 3 else { return displayPath }
        
        let first = components[0]
        let secondToLast = components[components.count - 2]
        let last = components[components.count - 1]
        
        let abbreviated = "\(first)…/\(secondToLast)/\(last)"
        
        if abbreviated.count > maxLength {
            return "…/\(secondToLast)/\(last)"
        }
        
        return abbreviated
    }
}

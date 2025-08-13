    //
    //  Untitled.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.08.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI

struct FileRowView: View {
    let file: CustomFile
    let isSelected: Bool
    let onTap: () -> Void
    
        // MARK: - Constants for styling
    var nameColor: Color {
        log.info(#function + " for file: \(file.nameStr)")
        if file.isDirectory {
            return FilePanelStyle.dirNameColor
        }
        if file.isSymbolicDirectory {
            return FilePanelStyle.symlinkDirNameColor
        }
        return FilePanelStyle.fileNameColor
    }
    
        // MARK: - View Body
    var body: some View {
        log.info(#function + " for file: \(file.nameStr)")
        return HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .interpolation(.high) // Improve visual quality for resized icons
                .frame(width: FilePanelStyle.iconSize, height: FilePanelStyle.iconSize)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1) // Subtle drop shadow for depth
                .contrast(1.12) // Slightly increase contrast
                .saturation(1.06) // Slightly richer colors
                .padding(.trailing, 6) // Breathing room between icon and text
            Text(file.nameStr)
                .foregroundColor(nameColor)
                .background(Color.clear)
            
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if isSelected {
                    Rectangle()
                        .fill(FilePanelStyle.selectedRowFill)
                        .overlay(
                            Rectangle()
                                .stroke(FilePanelStyle.selectedRowStroke, lineWidth: FilePanelStyle.selectedBorderWidth)
                        )
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

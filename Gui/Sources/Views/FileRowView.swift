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

    var nameColor: Color {
        if file.isDirectory {
            return FilePanelStyle.dirNameColor
        }
        if file.isSymbolicDirectory {
            return FilePanelStyle.symlinkDirNameColor
        }
        return FilePanelStyle.fileNameColor
    }

    var body: some View {
        HStack {
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
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                Rectangle()
                    .fill(FilePanelStyle.selectedRowFill)
                    .overlay(Rectangle().stroke(FilePanelStyle.selectedRowStroke, lineWidth: FilePanelStyle.selectedBorderWidth ))
            } else {
                Color.clear
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

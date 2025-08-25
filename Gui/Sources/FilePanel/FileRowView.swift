//
//  FileRowView.swift
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
        log.info(#function + " for '\(file.nameStr)'")
        return HStack {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                    .resizable()
                    .interpolation(.high) // Improve visual quality for resized icons
                    .frame(width: FilePanelStyle.iconSize, height: FilePanelStyle.iconSize)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1) // Subtle drop shadow for depth
                    .contrast(1.12) // Slightly increase contrast
                    .saturation(1.06) // Slightly richer colors
                    .padding(.trailing, 5) // Breathing room between icon and text
                    .allowsHitTesting(false)
                    .colorMultiply(file.isSymbolicDirectory ? Color(#colorLiteral(red: 0.2392601878, green: 0.7097211956, blue: 0.2428776343, alpha: 1)) : Color.white) // Highlight effect when selected

                if file.isSymbolicDirectory {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: FilePanelStyle.iconSize / 3, height: FilePanelStyle.iconSize / 3)
                        .foregroundColor(.orange) // Contrast arrow color
                        .shadow(radius: 1)
                        .offset(x: 0, y: 0)
                }
            }
            Text(file.nameStr).foregroundColor(nameColor).background(Color.clear)
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                if isSelected {
                    let stroke = Rectangle().stroke(FilePanelStyle.selectedRowStroke, lineWidth: FilePanelStyle.selectedBorderWidth) // blue border
                    Rectangle()
                        .fill(FilePanelStyle.selectedRowFill) // pale yellow fill
                        .overlay(stroke)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
    }
}

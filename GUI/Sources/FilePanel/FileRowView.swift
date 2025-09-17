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
    let isActivePanel: Bool  // ← добавили флаг активности панели

    // MARK: - Constants for styling
    var nameColor: Color {
        log.info(#function + " for file: \(file.nameStr)")
        if file.isDirectory { return FilePanelStyle.dirNameColor }
        if file.isSymbolicDirectory { return FilePanelStyle.blueSymlinkDirNameColor }
        return FilePanelStyle.fileNameColor
    }

    // MARK: - View Body
    var body: some View {
        log.info(#function + " for '\(file.nameStr)'")
        return HStack {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path)).resizable().interpolation(.high)  // Improve visual quality for resized icons
                    .frame(width: FilePanelStyle.iconSize, height: FilePanelStyle.iconSize).shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1)  // Subtle drop shadow for depth
                    .contrast(1.12)  // Slightly increase contrast
                    .saturation(1.06)  // Slightly richer colors
                    .padding(.trailing, 5)  // Breathing room between icon and text
                    .allowsHitTesting(false).colorMultiply(
                        file.isSymbolicDirectory
                            ?  Color(#colorLiteral(red: 0.5412748303, green: 0.9764705896, blue: 0.6294356168, alpha: 1)) : Color.white
                    )  // Highlight effect when selected
                    .shadow(color: (isSelected && isActivePanel) ? .gray.opacity(0.05) : .clear, radius: 4, x: 1, y: 1)

                if file.isSymbolicDirectory {
                    Image(systemName: "arrowshape.turn.up.right.fill").resizable().scaledToFit().frame(
                        width: FilePanelStyle.iconSize / 3, height: FilePanelStyle.iconSize / 3
                    ).foregroundColor(.orange)  // Contrast arrow color
                        .shadow(radius: 1).shadow(color: (isSelected && isActivePanel) ? .gray.opacity(0.05) : .clear, radius: 4, x: 1, y: 1)
                }
            }
            Text(file.nameStr).foregroundColor(nameColor)
        }.padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isSelected && isActivePanel) ? FilePanelStyle.yellowSelRowFill : Color.clear)
            .shadow(color: (isSelected && isActivePanel) ? .gray.opacity(0.05) : .clear, radius: 4, x: 1, y: 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected && isActivePanel)
            .contentShape(Rectangle())
    }
}


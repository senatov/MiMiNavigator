//
//  FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

struct FileRowView: View {
    @EnvironmentObject var appState: AppState
    let file: CustomFile
    let panelSide: PanelSide

    init(file: CustomFile, panelSide: PanelSide) {
        log.info(#function + " for '\(file.nameStr)' on side \(panelSide)")
        self.file = file
        self.panelSide = panelSide
    }
    // MARK: - View Body
    var body: some View {
        log.info(#function + " for '\(file.nameStr)'")
        return rowContainer(baseContent())
    }

    // MARK: - True when this row represents the selected file of the focused panel.
    private var isActiveSelection: Bool {
        switch panelSide {
        case .left: return appState.focusedPanel == .left && appState.selectedLeftFile == file
        case .right: return appState.focusedPanel == .right && appState.selectedRightFile == file
        }
    }

    // MARK: - Text color for the file name based on file attributes and selection state.
    private var nameColor: Color {
        if isActiveSelection { return .primary }  // keep readable on selected background
        if file.isSymbolicDirectory { return FilePanelStyle.fileNameColor }
        if file.isDirectory { return FilePanelStyle.dirNameColor }
        return .primary
    }

    // MARK: -  Base content for a single file row (icon + name) preserving original visuals.
    private func baseContent() -> some View {
        log.debug(#function + " for '\(file.nameStr)'")
        return HStack {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path)).resizable().interpolation(.high)  // Improve visual quality for resized icons
                    .frame(width: FilePanelStyle.iconSize, height: FilePanelStyle.iconSize)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1)  // Subtle drop shadow for depth
                    .contrast(1.12)  // Slightly increase contrast
                    .saturation(1.06)  // Slightly richer colors
                    .padding(.trailing, 5)  // Breathing room between icon and text
                    .allowsHitTesting(false)
                    .colorMultiply(
                        file.isSymbolicDirectory
                            ? Color(#colorLiteral(red: 0.3300087425, green: 0.5964453125, blue: 0.3848833733, alpha: 1))
                            : Color.white
                    )  // Highlight effect when selected
                    .shadow(color: isActiveSelection ? .gray.opacity(0.07) : .clear, radius: 4, x: 1, y: 1)

                if file.isSymbolicDirectory {
                    Image(systemName: "arrowshape.turn.up.right.fill").resizable().scaledToFit()
                        .frame(width: FilePanelStyle.iconSize / 3, height: FilePanelStyle.iconSize / 3)
                        .foregroundColor(.orange)  // Contrast arrow color
                        .shadow(radius: 1)
                        .shadow(color: isActiveSelection ? .gray.opacity(0.05) : .clear, radius: 4, x: 1, y: 1)
                }
            }
            Text(file.nameStr).foregroundColor(nameColor)
        }
    }

    // MARK: - Row Container with conditional debug logic
    private func rowContainer<Content: View>(_ content: Content) -> some View {
        log.debug("\(#function) for '\(file.nameStr)'") // Debug log
        var bkgColor: Color = .clear
        var shadowColor: Color = .clear
        if isActiveSelection {
            bkgColor = FilePanelStyle.yellowSelRowFill
            shadowColor = Color.gray.opacity(0.07)
        }
        let rowCnt = content
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bkgColor)
            .shadow(color: shadowColor, radius: 4, x: 1, y: 1)
        if isActiveSelection {
            log.debug("Active selection → applying animation & contentShape")
            return AnyView(
                rowCnt
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActiveSelection)
                    .contentShape(Rectangle())
            )
        } else {
            log.debug("Inactive row → returning without animation")
            return AnyView(rowCnt)
        }
    }
}

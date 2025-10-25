//
//  FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: -
struct FileRowView: View {
    @EnvironmentObject var appState: AppState
    let file: CustomFile
    let panelSide: PanelSide

    init(file: CustomFile, panelSide: PanelSide) {
        log.debug(#function + " for '\(file.nameStr)' on side <<\(panelSide)>>")
        self.file = file
        self.panelSide = panelSide
    }
    // MARK: - View Body
    var body: some View {
        log.debug(#function + " for '\(file.nameStr)'")
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
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                    .shadow(color: .black.opacity(0.08), radius: 0.5, x: 1, y: 1)
                    .padding(.trailing, RowDesignTokens.grid - 3)
                    .allowsHitTesting(false)
                if file.isSymbolicDirectory {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: RowDesignTokens.iconSize / 3, height: RowDesignTokens.iconSize / 3)
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.08), radius: 0.5, x: 1, y: 1)
                        .allowsHitTesting(false)
                }
            }
            Text(file.nameStr).foregroundColor(nameColor)
        }
    }

    // MARK: - Row Container with unified selection and hover visuals
    private func rowContainer<Content: View>(_ content: Content) -> some View {
        // Base content aligned to 8pt grid
        let base =
            content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, RowDesignTokens.grid / 2)
            .padding(.horizontal, RowDesignTokens.grid)
            .background(Color.clear)
            .contentShape(Rectangle())
        return base
    }
}

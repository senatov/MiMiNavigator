//
//  PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: -
struct PanelFileTableSection: View {
    @EnvironmentObject var appState: AppState
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]

    // MARK: - Selection coordination helpers
    private func notifyWillSelect(_ file: CustomFile) {
        // Let other parts know that this panel is about to select a row, so they can reset their own selections
        NotificationCenter.default.post(
            name: .panelWillSelectFile,
            object: nil,
            userInfo: [
                "panelSide": appState.focusedPanel,
                "fileID": file.id,
                "fileName": file.nameStr,
            ]
        )
    }

    // MARK: -
    private func notifyDidClearSelection() {
        NotificationCenter.default.post(
            name: .panelDidClearSelection,
            object: nil,
            userInfo: [
                "panelSide": appState.focusedPanel
            ]
        )
    }

    // MARK: -
    var body: some View {
        log.info(#function + " for side \(appState.focusedPanel)")
        return FileTableView(
            panelSide: appState.focusedPanel,
            files: files,
            selectedID: $selectedID,
            onSelect: onSelect  // ← вместо { _ in }
        )
        .coordinateSpace(name: "fileTableSpace")
        .onPreferenceChange(RowRectPreference.self) { value in
            rowRects = value
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { g in
                if let id = selectedID, let rect = rowRects[id] {
                    let y = rect.minY
                    let h = rect.height
                    let w = g.size.width
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FilePanelStyle.yellowSelRowFill)
                            .frame(width: w, height: h)
                            .offset(x: 0, y: y)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                FilePanelStyle.blueSymlinkDirNameColor, lineWidth: FilePanelStyle.selectedBorderWidth
                            )
                            .frame(width: w, height: h)
                            .offset(x: 0, y: y)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        // Unified click area for the table — keep previous behavior and style
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onPanelTap(appState.focusedPanel)
                    log.info("table tap (simultaneous) on side \(appState.focusedPanel)")
                }
        )
        // React to selection changes
        .onChange(of: selectedID, initial: false) { _, newValue in
            log.info("on onChange on table, side \(appState.focusedPanel)")
            if let id = newValue, let file = files.first(where: { $0.id == id }) {
                log.info("Row selected: id=\(id) on side \(appState.focusedPanel)")
                // Notify others to clear their selections before we commit this one
                notifyWillSelect(file)
                onSelect(file)
            } else {
                log.info("Selection cleared on \(appState.focusedPanel)")
                notifyDidClearSelection()
            }
        }
        // Navigation with arrow keys — same as before
        .onMoveCommand { direction in
            switch direction {
                case .up,
                    .down:
                    log.info("Move command: \(direction) on side \(appState.focusedPanel)")
                    DispatchQueue.main.async {
                        if let id = selectedID, let file = files.first(where: { $0.id == id }) {
                            notifyWillSelect(file)
                            onSelect(file)
                        } else {
                            log.info("Move command but no selection on \(appState.focusedPanel)")
                        }
                    }

                default:
                    log.info("on onMoveCommand on table, side \(appState.focusedPanel)")
            }
        }
    }
}

extension Notification.Name {
    /// Posted right before a panel is about to select a file so others can reset their selections
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
    /// Posted when a panel cleared its selection
    static let panelDidClearSelection = Notification.Name("PanelDidClearSelection")
}

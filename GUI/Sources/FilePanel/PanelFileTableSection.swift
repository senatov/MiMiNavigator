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
    let panelSide: PanelSide
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]
    @FocusState private var isFocused: Bool
    
        // MARK: -
    var body: some View {
        log.debug(#function + " for side <<\(panelSide)>>")
        return FileTableView(
            panelSide: panelSide,
            files: files,
            selectedID: $selectedID,
            onSelect: onSelect  // ← вместо { _ в }
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($isFocused)
        .coordinateSpace(name: "fileTableSpace")
        .onPreferenceChange(RowRectPreference.self) { value in
            rowRects = value
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    isFocused = true
                    appState.focusedPanel = panelSide
                    onPanelTap(panelSide)
                    log.debug("table tap (highPriority) on side <<\(panelSide)>>")
                        // Ensure there is a visible selection immediately upon panel tap
                    if selectedID == nil, let first = files.first {
                        log.debug("Auto-select first row on tap for side <<\(panelSide)>>: \(first.nameStr)")
                        selectedID = first.id  // Update binding for row highlights
                        onSelect(first)  // Propagate to ViewModel/AppState immediately
                    }
                }
        )
            // React to selection changes
        .onChange(of: selectedID, initial: false) { _, newValue in
            appState.focusedPanel = panelSide
            log.debug("on onChange on table, side <<\(panelSide)>>")
            if let id = newValue, let file = files.first(where: { $0.id == id }) {
                log.debug("Row selected: id=\(id) on side <<\(panelSide)>>")
                    // Notify others to clear their selections before we commit this one
                notifyWillSelect(file)
                onSelect(file)
            } else {
                log.debug("Selection cleared on \(panelSide)")
                notifyDidClearSelection()
            }
        }
            // Navigation with arrow keys — same as before
        .onMoveCommand { direction in
            appState.focusedPanel = panelSide
            switch direction {
                case .up,
                        .down:
                    log.debug("Move command: \(direction) on side <<\(panelSide)>>")
                    DispatchQueue.main.async {
                        if let id = selectedID, let file = files.first(where: { $0.id == id }) {
                            notifyWillSelect(file)
                            onSelect(file)
                        } else {
                            log.debug("Move command but no selection on <<\(panelSide)>>")
                        }
                    }
                default:
                    log.debug("on onMoveCommand on table, side <<\(panelSide)>>")
            }
        }
        .onChange(of: appState.focusedPanel, initial: false) { _, newSide in
                // When this panel receives keyboard focus (e.g., via Tab), ensure a visible selection exists
            guard newSide == panelSide else { return }
            isFocused = true
            if selectedID == nil, let first = files.first {
                log.debug("Auto-select first row on focusedPanel change for side <<\(panelSide)>>: \(first.nameStr)")
                selectedID = first.id
                onSelect(first)
            } else {
                log.debug("focusedPanel change on <<\(panelSide)>> but selection already present: \(String(describing: selectedID))")
            }
        }
        .onChange(of: isFocused, initial: false) { _, nowFocused in
            log.debug("Panel focus state changed (FocusState) for <<\(panelSide)>>: \(nowFocused)")
            if nowFocused {
                appState.focusedPanel = panelSide
                if selectedID == nil, let first = files.first {
                    log.debug("FocusState gained, auto-select first on <<\(panelSide)>>: \(first.nameStr)")
                    selectedID = first.id
                    onSelect(first)
                } else {
                    log.debug("FocusState gained on <<\(panelSide)>>, selection exists: \(String(describing: selectedID))")
                }
            }
        }
        .animation(nil, value: selectedID)
        .animation(nil, value: isFocused)
        .transaction { txn in
            txn.disablesAnimations = true
        }
        .id("PFTS_\(panelSide)_\(String(describing: selectedID))")
    }
    
        // MARK: - Selection coordination helpers
    private func notifyWillSelect(_ file: CustomFile) {
            // Let other parts know that this panel is about to select a row, so they can reset their own selections
        NotificationCenter.default.post(
            name: .panelWillSelectFile,
            object: nil,
            userInfo: [
                "panelSide": panelSide,
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
                "panelSide": panelSide
            ]
        )
    }
}

extension Notification.Name {
        /// Posted right before a panel is about to select a file so others can reset their selections
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
        /// Posted when a panel cleared its selection
    static let panelDidClearSelection = Notification.Name("PanelDidClearSelection")
}

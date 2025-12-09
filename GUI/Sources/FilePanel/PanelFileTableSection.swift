//
// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: -
struct PanelFileTableSection: View {
    @Environment(AppState.self) var appState
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]
    @FocusState private var isFocused: Bool

    // Throttle for body logs without mutating SwiftUI state
    @MainActor
    private enum LogThrottle {
        static var last: TimeInterval = 0
    }

    // MARK: -
    var body: some View {
        // Throttled logging - only log every 1 second max
        let now = ProcessInfo.processInfo.systemUptime
        if now - LogThrottle.last >= 1.0 {
            LogThrottle.last = now
            log.debug(#function + " side= <<\(panelSide)>> files=\(files.count) sel=\(String(describing: selectedID))")
        }
        let stableKey = files.count.hashValue ^ (selectedID?.hashValue ?? 0) ^ panelSide.hashValue
        return StableBy(stableKey) {
            FileTableView(
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
                if value != rowRects {
                    rowRects = value
                }
            }
            // React to sel changes
            .onChange(of: selectedID, initial: false) { _, newValue in
                log.debug(
                    "[SELECT-FLOW] 5️⃣ PanelFileTableSection.onChange(selectedID): \(String(describing: newValue)) on <<\(panelSide)>>")
                appState.focusedPanel = panelSide
                if let id = newValue, let file = files.first(where: { $0.id == id }) {
                    log.debug("[SELECT-FLOW] 5️⃣ File found: \(file.nameStr), notifying & calling onSelect")
                    notifyWillSelect(file)
                    onSelect(file)
                } else {
                    log.debug("[SELECT-FLOW] 5️⃣ Selection cleared, notifying")
                    notifyDidClearSelection()
                }
                log.debug("[SELECT-FLOW] 5️⃣ DONE")
            }
            // Nav with arrow keys — same as before
            .onMoveCommand { direction in
                appState.focusedPanel = panelSide
                switch direction {
                    case .up,
                        .down:
                        log.debug("Move command: \(direction) on side <<\(panelSide)>>")
                        Task { @MainActor in
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
                // When panel receives focus via Tab, update FocusState
                guard newSide == panelSide else { return }
                isFocused = true
                log.debug("focusedPanel changed to <<\(panelSide)>>, selection: \(String(describing: selectedID))")
            }
            .onChange(of: isFocused, initial: false) { _, nowFocused in
                log.debug("Panel focus state changed (FocusState) for <<\(panelSide)>>: \(nowFocused)")
                if nowFocused {
                    appState.focusedPanel = panelSide
                    log.debug("FocusState gained on <<\(panelSide)>>, selection: \(String(describing: selectedID))")
                }
            }
            .animation(nil, value: selectedID)
            .animation(nil, value: isFocused)
            .transaction { txn in
                txn.disablesAnimations = true
            }
            .id("PFTS_\(panelSide)")
        }
    }

    // MARK: - Selection coordination helpers
    private func notifyWillSelect(_ file: CustomFile) {
        // Let other parts know that this panel is about->select a row, so they can reset their own sels
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
    // / Posted right before a panel is about->select a file so others can reset their sels
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
    // / Posted when a panel cleared its sel
    static let panelDidClearSelection = Notification.Name("PanelDidClearSelection")
}

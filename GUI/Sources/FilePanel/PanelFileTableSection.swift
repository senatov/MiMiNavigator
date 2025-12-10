//
// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - PanelFileTableSection
struct PanelFileTableSection: View {
    @Environment(AppState.self) var appState
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]
    @FocusState private var isFocused: Bool

    // Throttle for body logs without mutating SwiftUI state
    @MainActor
    private enum LogThrottle {
        static var last: TimeInterval = 0
    }

    // MARK: - Body
    var body: some View {
        // Throttled logging
        let now = ProcessInfo.processInfo.systemUptime
        if now - LogThrottle.last >= 1.0 {
            LogThrottle.last = now
            log.debug(#function + " side=<<\(panelSide)>> files=\(files.count) sel=\(String(describing: selectedID))")
        }
        let stableKey = files.count.hashValue ^ (selectedID?.hashValue ?? 0) ^ panelSide.hashValue
        return StableBy(stableKey) {
            FileTableView(
                panelSide: panelSide,
                files: files,
                selectedID: $selectedID,
                onSelect: handleSelection,
                onDoubleClick: onDoubleClick
            )
            .contentShape(Rectangle())
            // Use simultaneousGesture to activate panel on ANY click without blocking child clicks
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        if appState.focusedPanel != panelSide {
                            log.debug("[PANEL-ACTIVATE] simultaneousGesture activating <<\(panelSide)>>")
                            appState.focusedPanel = panelSide
                            isFocused = true
                        }
                    }
            )
            .focusable(true)
            .focused($isFocused)
            .coordinateSpace(name: "fileTableSpace")
            .onPreferenceChange(RowRectPreference.self) { value in
                if value != rowRects {
                    rowRects = value
                }
            }
            // Arrow key navigation
            .onMoveCommand { direction in
                appState.focusedPanel = panelSide
                switch direction {
                    case .up, .down:
                        log.debug("Move command: \(direction) on side <<\(panelSide)>>")
                        if let id = selectedID, let file = files.first(where: { $0.id == id }) {
                            notifyWillSelect(file)
                        }
                    default:
                        log.debug("Unhandled move command on table, side <<\(panelSide)>>")
                }
            }
            // Tab-navigation: sync FocusState when panel receives focus externally
            .onChange(of: appState.focusedPanel, initial: false) { _, newSide in
                guard newSide == panelSide else { return }
                isFocused = true
                log.debug("onChange(focusedPanel) <<\(panelSide)>> → isFocused=true")
            }
            // Reverse sync: when FocusState changes, update appState
            .onChange(of: isFocused, initial: false) { _, nowFocused in
                log.debug("onChange(isFocused) <<\(panelSide)>>: \(nowFocused)")
                if nowFocused && appState.focusedPanel != panelSide {
                    appState.focusedPanel = panelSide
                    log.debug("FocusState gained on <<\(panelSide)>>")
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

    // MARK: - Unified selection handler (single point of truth)
    /// Called when user clicks a row. Handles both activation and selection in one place.
    private func handleSelection(_ file: CustomFile) {
        log.debug("[SELECT-FLOW] PanelFileTableSection.handleSelection: \(file.nameStr) on <<\(panelSide)>>")

        // 1. Activate panel (even if clicking on already-active panel)
        let wasInactive = appState.focusedPanel != panelSide
        if wasInactive {
            log.debug("[SELECT-FLOW] Activating inactive panel <<\(panelSide)>>")
        }
        appState.focusedPanel = panelSide

        // 2. Notify other panels to clear their selection
        notifyWillSelect(file)

        // 3. Forward to parent's onSelect
        onSelect(file)

        log.debug("[SELECT-FLOW] handleSelection complete")
    }

    // MARK: - Selection coordination helpers
    private func notifyWillSelect(_ file: CustomFile) {
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

}

// MARK: - Notification Names
extension Notification.Name {
    /// Posted right before a panel is about to select a file so others can reset their selections
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
}

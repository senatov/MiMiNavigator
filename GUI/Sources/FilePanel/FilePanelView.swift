//
// FilePanelView.swift
//  MiMiNavigator
//
// Restored+refactored: keeps clean components+adds custom row highlight
//

import AppKit
import SwiftUI

// MARK: - FilePanelView
struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: FilePanelViewModel
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    // / Called when user clicks anywhere inside the panel (left/right)
    let onPanelTap: (PanelSide) -> Void
    @State private var lastBodyLogTime: TimeInterval = 0

    // MARK: - compound Variable: Bridge binding to AppState-selected file for this panel
    private var selectedIDBinding: Binding<CustomFile.ID?> {
        Binding<CustomFile.ID?>(
            get: {
                switch viewModel.panelSide {
                    case .left:
                        return appState.selectedLeftFile?.id
                    case .right:
                        return appState.selectedRightFile?.id
                }
            },
            set: { newValue in
                // We only handle clearing via binding. Non-nil sel is set via onSelect below.
                if newValue == nil {
                    log.debug("Clearing selection via binding for side <<\(viewModel.panelSide)>>")
                    switch viewModel.panelSide {
                        case .left:
                            appState.selectedLeftFile = nil
                        case .right:
                            appState.selectedRightFile = nil
                    }
                    appState.selectedDir.selectedFSEntity = nil
                    appState.showFavTreePopup = false
                }
            }
        )
    }

    // MARK: - Init
    init(
        selectedSide: PanelSide,
        geometry: GeometryProxy,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
        appState: AppState,
        onPanelTap: @escaping (PanelSide) -> Void = { side in log.debug("onPanelTap default for \(side)") }
    ) {
        self._leftPanelWidth = leftPanelWidth
        self.geometry = geometry
        self._viewModel = StateObject(
            wrappedValue: FilePanelViewModel(
                panelSide: selectedSide,
                appState: appState,
                fetchFiles: fetchFiles
            ))
        self.onPanelTap = onPanelTap
    }

    // MARK: - View
    var body: some View {
        let currentPath = appState.pathURL(for: viewModel.panelSide)
        return VStack {
            StableBy(currentPath?.path ?? "") {
                PanelBreadcrumbSection(
                    currentPath: currentPath,
                    onPathChange: { newValue in
                        viewModel.handlePathChange(to: newValue)
                    }
                )
            }
            StableBy((currentPath?.path ?? "") + "|" + String(appState.focusedPanel == viewModel.panelSide)) {
                PanelFileTableSection(
                    files: viewModel.sortedFiles,
                    selectedID: selectedIDBinding,
                    panelSide: viewModel.panelSide,
                    onPanelTap: onPanelTap,
                    onSelect: { file in
                        // central sel; will clear the other panel via ViewModel.select(_:)
                        viewModel.select(file)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                GeometryReader { gp in
                    Color.clear
                        .onAppear {
                            log.debug(
                                "PFT.section appear → size=\(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(viewModel.panelSide)>>")
                        }
                        .onChange(of: gp.size) {
                            let now = ProcessInfo.processInfo.systemUptime
                            if now - lastBodyLogTime >= 0.25 {
                                lastBodyLogTime = now
                                log.debug(
                                    "PFT.section size changed → \(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(viewModel.panelSide)>>"
                                )
                            }
                        }
                }
            )
        }
        .onAppear {
            // Log once on first appearance; no throttling needed here
            let pathStr = appState.pathURL(for: viewModel.panelSide)?.path ?? "nil"
            log.debug("FilePanelView.onAppear side= <<\(viewModel.panelSide)>> path=\(pathStr)")
        }
        .onChange(of: appState.pathURL(for: viewModel.panelSide)?.path) { oldValue, newValue in
            // Throttle path-change logs to avoid noise on rapid updates
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastBodyLogTime >= 0.25 {
                lastBodyLogTime = now
                log.debug("FilePanelView.path changed side= <<\(viewModel.panelSide)>> → \(newValue ?? "nil")")
            }
        }
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                    .fill(DesignTokens.card)
                RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                    .stroke(DesignTokens.separator.opacity(0.35), lineWidth: 1)
            }
            .drawingGroup()  // flatten vector ops for cheaper compositing during drags
        )
        .frame(
            width: viewModel.panelSide == .left
                ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
                : nil
        )
        .animation(nil, value: leftPanelWidth)
        .transaction { tx in
            tx.disablesAnimations = true
            tx.animation = nil
        }
        .background(DesignTokens.panelBg)
        .controlSize(.regular)
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    // Focus panel on any click within its bounds without stealing row taps
                    log.debug("Panel tapped for focus: <<\(viewModel.panelSide)>>")
                    onPanelTap(viewModel.panelSide)
                    // Sel is coordinated inside PanelFileTableSection; do not auto-select here->avoid double handling
                }
        )
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on << \(viewModel.panelSide)>>; keep selection")
            appState.showFavTreePopup = false
        }
        .onChange(of: appState.focusedPanel) { oldSide, newSide in
            // Run only when focus actually changes to this panel
            guard newSide == viewModel.panelSide, oldSide != newSide else { return }

            // If this panel just became focus'd and has no sel, select the first row
            let files = viewModel.sortedFiles
            if selectedIDBinding.wrappedValue == nil, let first = files.first {
                log.debug("Auto-select on focus gain (<<\(viewModel.panelSide))>>: \(first.nameStr)")
                viewModel.select(first)
            }

            // Clear opposite side sel to avoid dual highlight
            switch viewModel.panelSide {
                case .left:
                    if appState.selectedRightFile != nil {
                        log.debug("Clearing RIGHT selection due to <<LEFT>> focus gain")
                        appState.selectedRightFile = nil
                    }
                case .right:
                    if appState.selectedLeftFile != nil {
                        log.debug("Clearing LEFT selection due to <<RIGHT>> focus gain")
                        appState.selectedLeftFile = nil
                    }
            }
        }
    }
}

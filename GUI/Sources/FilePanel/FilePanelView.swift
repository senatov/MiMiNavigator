    //
    //  FilePanelView.swift
    //  MiMiNavigator
    //
    //  Restored and refactored: keeps clean components and adds custom row highlight
    //

import AppKit
import SwiftUI

    // MARK: - FilePanelView
struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: FilePanelViewModel
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
        /// Called when user clicks anywhere inside the panel (left/right)
    let onPanelTap: (PanelSide) -> Void
    
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
                    // We only handle clearing via the binding. Non-nil selection is set via onSelect below.
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
        log.debug(#function + " for side <<\(viewModel.panelSide)>> with path: \(currentPath?.path ?? "nil")")
        return VStack {
            PanelBreadcrumbSection(
                currentPath: currentPath,
                onPathChange: { newValue in
                    viewModel.handlePathChange(to: newValue)
                }
            )
            PanelFileTableSection(
                files: viewModel.sortedFiles,
                selectedID: selectedIDBinding,
                panelSide: viewModel.panelSide,
                onPanelTap: onPanelTap,
                onSelect: { file in
                        // Centralized selection; will clear the other panel via ViewModel.select(_:)
                    viewModel.select(file)
                }
            )
        }
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(DesignTokens.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .stroke(DesignTokens.separator.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .frame(
            width: viewModel.panelSide == .left
            ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
            : nil
        )
        .background(DesignTokens.panelBg)
        .controlSize(.regular)
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                        // Focus the panel on any click within its bounds without stealing row taps
                    log.debug("Panel tapped for focus: \(viewModel.panelSide)")
                    onPanelTap(viewModel.panelSide)
                        // Selection is coordinated inside PanelFileTableSection; do not auto-select here to avoid double handling
                }
        )
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on \(viewModel.panelSide); keep selection")
            appState.showFavTreePopup = false
        }
        .onChange(of: appState.focusedPanel) { newSide in
            guard newSide == viewModel.panelSide else { return }
            
                // If this panel just became focused and has no selection, select the first row
            let files = viewModel.sortedFiles
            if selectedIDBinding.wrappedValue == nil, let first = files.first {
                log.debug("Auto-select on focus gain (\(viewModel.panelSide)): \(first.nameStr)")
                viewModel.select(first)
            }
            
                // Clear opposite side selection to avoid dual highlight
            switch viewModel.panelSide {
                case .left:
                    if appState.selectedRightFile != nil {
                        log.debug("Clearing RIGHT selection due to LEFT focus gain")
                        appState.selectedRightFile = nil
                    }
                case .right:
                    if appState.selectedLeftFile != nil {
                        log.debug("Clearing LEFT selection due to RIGHT focus gain")
                        appState.selectedLeftFile = nil
                    }
            }
        }
    }
}

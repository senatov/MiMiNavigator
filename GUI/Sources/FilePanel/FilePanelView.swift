    //
    //  FilePanelView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 24.06.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI

    // MARK: - FilePanelView
struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: FilePanelViewModel
    var geometry: GeometryProxy
    let containerSize: CGSize
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
        containerSize: CGSize,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
        appState: AppState,
        onPanelTap: @escaping (PanelSide) -> Void = { side in log.debug("onPanelTap default for \(side)") }
    ) {
        self._leftPanelWidth = leftPanelWidth
        self.geometry = geometry
        self.containerSize = containerSize
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
                // Inner content container with internal padding only
            VStack(spacing: DesignTokens.grid - 2) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(
                    GeometryReader { gp in
                        Color.clear
                            .onAppear {
                                log.debug(
                                    "PFT.section appear → size=\(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(viewModel.panelSide)>>"
                                )
                            }
                            .onChange(of: gp.size) {
                                log.debug(
                                    "PFT.section size changed → \(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(viewModel.panelSide)>>"
                                )
                            }
                    }
                )
            }
            .padding(.horizontal, DesignTokens.grid)
            .padding(.vertical, DesignTokens.grid - 2)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(DesignTokens.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .stroke(DesignTokens.separator.opacity(0.35), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .stroke(
                    appState.focusedPanel == viewModel.panelSide ? FilePanelStyle.dirNameColor.opacity(0.95) : .clear, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped(antialiased: true)
        .contentShape(Rectangle())
        .transaction { $0.disablesAnimations = true }
        .animation(nil, value: appState.focusedPanel)
        .background(DesignTokens.panelBg)
        .controlSize(.regular)
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on \(viewModel.panelSide); keep selection")
            appState.showFavTreePopup = false
        }
        .onChange(of: appState.focusedPanel) { oldSide, newSide in
                // Skip redundant or recursive focus updates
            guard newSide != oldSide else { return }
            log.debug("onChange(focusedPanel): \(oldSide) → \(newSide) on <<\(viewModel.panelSide)>>")
            
                // Only act if this panel is the newly focused one
            guard newSide == viewModel.panelSide else {
                log.debug("Focus moved away from <<\(viewModel.panelSide)>> → ignoring")
                return
            }
            
                // Avoid re-entrance: do not auto-select again if already selecting or already has selection
            if selectedIDBinding.wrappedValue != nil {
                log.debug("Already has selection on <<\(viewModel.panelSide)>> → skip auto-select")
            } else if let first = viewModel.sortedFiles.first {
                log.debug("Auto-selecting first item on <<\(viewModel.panelSide)>>: \(first.nameStr)")
                    // Call select with a minimal guard to prevent triggering another focus update
                if appState.focusedPanel == viewModel.panelSide {
                    viewModel.select(first)
                }
            }
            
        }
    }
}

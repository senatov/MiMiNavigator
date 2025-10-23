//
//  FilePanelView.swift
//  MiMiNavigator
//
//  Restored and refactored: keeps clean components and adds custom row highlight
//

import AppKit
import SwiftUI

// Design tokens aligned with Figma macOS 26.1 (8pt grid, system materials)
private enum DesignTokens {
    static let grid: CGFloat = 8
    static let radius: CGFloat = 8
    static let card = Color(nsColor: .windowBackgroundColor)
    static let panelBg = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
}

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
        onPanelTap: @escaping (PanelSide) -> Void = { side in log.info("onPanelTap default for \(side)") }
    ) {
        log.debug(#function + " for side <<\(selectedSide)>>" + " with leftPanelWidth: \(leftPanelWidth.wrappedValue.rounded())")
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
                panelSide: <#PanelSide#>,
                files: viewModel.sortedFiles,
                selectedID: selectedIDBinding,
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
                }
        )
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on \(viewModel.panelSide); clearing selection")
            switch viewModel.panelSide {
                case .left:
                    appState.selectedLeftFile = nil
                case .right:
                    appState.selectedRightFile = nil
            }
            appState.selectedDir.selectedFSEntity = nil
            appState.showFavTreePopup = false
            log.debug("Cleared selection due to focus loss for side <<\(viewModel.panelSide)>>")
        }
    }
}

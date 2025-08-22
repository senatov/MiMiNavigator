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
    // MARK: - Init
    init(selectedSide: PanelSide,
         geometry: GeometryProxy,
         leftPanelWidth: Binding<CGFloat>,
         fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
         appState: AppState,
         onPanelTap: @escaping (PanelSide) -> Void = { side in log.debug("onPanelTap default for \(side)") })
    {
        self._leftPanelWidth = leftPanelWidth
        self.geometry = geometry
        self._viewModel = StateObject(wrappedValue: FilePanelViewModel(
            panelSide: selectedSide,
            appState: appState,
            fetchFiles: fetchFiles
        ))
        self.onPanelTap = onPanelTap
    }
    
    // MARK: - View
    var body: some View {
        let currentPath = appState.pathURL(for: viewModel.panelSide)
        log.info(#function + " for side \(viewModel.panelSide) with path: \(currentPath?.path ?? "nil")")
        
        return VStack {
            PanelBreadcrumbSection(
                panelSide: viewModel.panelSide,
                currentPath: currentPath,
                onPathChange: { newValue in
                    viewModel.handlePathChange(to: newValue)
                }
            )
            PanelFileTableSection(
                files: viewModel.sortedFiles,
                selectedID: $viewModel.selectedFileID,
                panelSide: viewModel.panelSide,
                onPanelTap: onPanelTap,
                onSelect: { file in
                    viewModel.select(file)
                }
            )
        }
        .frame(width: viewModel.panelSide == .left
            ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
            : nil)
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on \(viewModel.panelSide); clearing selection")
            viewModel.selectedFileID = nil
        }
    }
    

    
  
}

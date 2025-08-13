//
//  FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: FilePanelViewModel
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat

    // MARK: - -
    init(selectedSide: PanelSide, geometry: GeometryProxy, leftPanelWidth: Binding<CGFloat>,
         fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void, appState: AppState)
    {
        // NOTE: SwiftUI requires _StateObject initialization in init; we pass the environment appState explicitly from the parent.
        log.info(#function + " for side \(selectedSide) with width: \(leftPanelWidth.wrappedValue)")
        _viewModel = StateObject(wrappedValue: FilePanelViewModel(panelSide: selectedSide, appState: appState, fetchFiles: fetchFiles))
        self.geometry = geometry
        self._leftPanelWidth = leftPanelWidth
    }

    // MARK: - View
    var body: some View {
        log.info(#function + " for side \(viewModel.panelSide) with width: \(leftPanelWidth)")
        let currentPath = appState.pathURL(for: viewModel.panelSide)
        log.info(#function + " for side \(viewModel.panelSide) with path: \(currentPath?.path ?? "nil")")
        return VStack {
            makeBreadCrumb(currentPath: currentPath)
            makeFileTable()
        }
        .frame(width: viewModel.panelSide == .left
            ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
            : nil)
    }

    // MARK: - - Creates the breadcrumb control with an onChange handler for path updates.
    private func makeBreadCrumb(currentPath: URL?) -> some View {
        log.info(#function + " for side \(viewModel.panelSide) with current path: \(currentPath?.path ?? "nil")")
        return BreadCrumbControlWrapper(selectedSide: viewModel.panelSide)
            .onChange(of: currentPath) { _, newValue in
                viewModel.handlePathChange(to: newValue)
            }
    }

    // MARK: - - Creates the file table view with selection handling.
    private func makeFileTable() -> some View {
        log.info(#function + " for side \(viewModel.panelSide)")
        return FileTableView(
            files: viewModel.sortedFiles,
            selectedID: $viewModel.selectedFileID,
            onSelect: { file in viewModel.select(file) }
        )
    }
}

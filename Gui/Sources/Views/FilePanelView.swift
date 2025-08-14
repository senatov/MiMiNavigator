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

    // MARK: - Init
    init(selectedSide: PanelSide,
         geometry: GeometryProxy,
         leftPanelWidth: Binding<CGFloat>,
         fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
         appState: AppState)
    {
        self._leftPanelWidth = leftPanelWidth
        self.geometry = geometry
        self._viewModel = StateObject(wrappedValue: FilePanelViewModel(
            panelSide: selectedSide,
            appState: appState,
            fetchFiles: fetchFiles
        ))
    }

    // MARK: - View
    var body: some View {
        log.info(#function + " for side \(viewModel.panelSide) with width: \(leftPanelWidth)")
        let currentPath = appState.pathURL(for: viewModel.panelSide)
        log.info(#function + " for side \(viewModel.panelSide) with path: \(currentPath?.path ?? "nil")")

        return buildPanelContent(currentPath: currentPath)
            .frame(width: viewModel.panelSide == .left
                ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
                : nil)
            .panelFocus(panelSide: viewModel.panelSide) {
                log.debug("Focus lost on \(viewModel.panelSide); clearing selection")
                viewModel.selectedFileID = nil
            }
    }

    // MARK: - Content
    private func buildPanelContent(currentPath: URL?) -> some View {
        log.info(#function + " for side \(viewModel.panelSide)")
        return VStack {
            buildBreadcrumbSection(currentPath: currentPath)
            buildFileTableSection()
        }
    }

    // MARK: - Sections
    private func buildBreadcrumbSection(currentPath: URL?) -> some View {
        log.info(#function + " for side \(viewModel.panelSide) with current path: \(currentPath?.path ?? "nil")")
        return BreadCrumbControlWrapper(selectedSide: viewModel.panelSide)
            .onChange(of: currentPath, initial: false) { _, newValue in
                viewModel.handlePathChange(to: newValue)
            }
    }

    // MARK: - Reacts to: left-click, selection changes, and keyboard up/down moves
    private func buildFileTableSection() -> some View {
        log.info(#function + " for side \(viewModel.panelSide)")
        return FileTableView(
            files: viewModel.sortedFiles,
            selectedID: $viewModel.selectedFileID,
            onSelect: { _ in } // not used; selection is handled via onChange/tap/move
        )
        // Left-click anywhere on the table: ensure current selection is handled
        .contentShape(Rectangle())
        .onTapGesture {
            log.debug("on onTapGesture on table, side \(viewModel.panelSide)")
            if let id = viewModel.selectedFileID,
               let file = viewModel.sortedFiles.first(where: { $0.id == id })
            {
                viewModel.select(file)
            } else {
                log.debug("L-click but no selection on \(viewModel.panelSide)")
            }
        }
        // Any selection change (mouse, keyboard, programmatic)
        .onChange(of: viewModel.selectedFileID, initial: false) { _, newValue in
            log.debug("on onChange on table, side \(viewModel.panelSide)")
            if let id = newValue,
               let file = viewModel.sortedFiles.first(where: { $0.id == id })
            {
                log.debug("Row selected: id=\(id) on side \(viewModel.panelSide)")
                viewModel.select(file)
            } else {
                log.debug("Selection cleared on \(viewModel.panelSide)")
            }
        }
        // Keyboard navigation: up/down arrows (fires before NSTableView updates selection)
        // We re-check selection on the next runloop tick to reflect the new row.
        .onMoveCommand { direction in
            switch direction {
            case .up,
                 .down:
                log.debug("Move command: \(direction) on side \(viewModel.panelSide)")
                DispatchQueue.main.async {
                    if let id = viewModel.selectedFileID,
                       let file = viewModel.sortedFiles.first(where: { $0.id == id })
                    {
                        viewModel.select(file)
                    } else {
                        log.debug("Move command but no selection on \(viewModel.panelSide)")
                    }
                }
            default:
                log.debug("on onMoveCommand on table, side \(viewModel.panelSide)")
                break
            }
        }
    }
}

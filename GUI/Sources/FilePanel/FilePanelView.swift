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
    @Environment(AppState.self) var appState
    @State private var viewModel: FilePanelViewModel
    let containerWidth: CGFloat
    @Binding var leftPanelWidth: CGFloat
    // / Called when user clicks anywhere inside the panel (left/right)
    let onPanelTap: (PanelSide) -> Void

    // MARK: - compound Variable: Bridge binding to AppState-selected file for this panel
    private var selectedIDBinding: Binding<CustomFile.ID?> {
        Binding<CustomFile.ID?>(
            get: {
                let result: CustomFile.ID?
                switch viewModel.panelSide {
                    case .left:
                        result = appState.selectedLeftFile?.id
                    case .right:
                        result = appState.selectedRightFile?.id
                }
                // Log removed - too verbose, floods console
                return result
            },
            set: { newValue in
                log.debug("[SELECT-FLOW] 7️⃣ selectedIDBinding.SET on <<\(viewModel.panelSide)>>: \(newValue ?? "nil")")
                // We only handle clearing via binding. Non-nil sel is set via onSelect below.
                if newValue == nil {
                    log.debug("[SELECT-FLOW] 7️⃣ Clearing selection via binding")
                    switch viewModel.panelSide {
                        case .left:
                            appState.selectedLeftFile = nil
                        case .right:
                            appState.selectedRightFile = nil
                    }
                    appState.selectedDir.selectedFSEntity = nil
                    appState.showFavTreePopup = false
                }
                log.debug("[SELECT-FLOW] 7️⃣ DONE")
            }
        )
    }

    // MARK: - Init
    init(
        selectedSide: PanelSide,
        containerWidth: CGFloat,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
        appState: AppState,
        onPanelTap: @escaping (PanelSide) -> Void = { side in log.debug("onPanelTap default for \(side)") }
    ) {
        self._leftPanelWidth = leftPanelWidth
        self.containerWidth = containerWidth
        self._viewModel = State(
            initialValue: FilePanelViewModel(
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
                    panelSide: viewModel.panelSide,
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
                    },
                    onDoubleClick: { file in
                        handleDoubleClick(file)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Log once on first appearance; no throttling needed here
            let pathStr = appState.pathURL(for: viewModel.panelSide)?.path ?? "nil"
            log.debug("FilePanelView.onAppear side= <<\(viewModel.panelSide)>> path=\(pathStr)")
        }
        .onChange(of: appState.pathURL(for: viewModel.panelSide)?.path) { _, newValue in
            log.debug("FilePanelView.path changed side= <<\(viewModel.panelSide)>> → \(newValue ?? "nil")")
        }
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                    .fill(DesignTokens.card)
                RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                    .stroke(
                        appState.focusedPanel == viewModel.panelSide
                            ? Color.orange.opacity(0.5)
                            : DesignTokens.separator.opacity(0.35),
                        lineWidth: 1
                    )
            }
            .drawingGroup()  // flatten vector ops for cheaper compositing during drags
        )
        .frame(
            width: viewModel.panelSide == .left
                ? (leftPanelWidth > 0 ? leftPanelWidth : containerWidth / 2)
                : nil
        )
        .animation(nil, value: leftPanelWidth)
        .transaction { tx in
            tx.disablesAnimations = true
            tx.animation = nil
        }
        .background(DesignTokens.panelBg)
        .controlSize(.regular)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                // This tap works simultaneously with FileRow taps
                // Sets focus when clicking empty space or on rows
                log.debug("Panel tapped for focus (simultaneous): <<\(viewModel.panelSide)>>")
                appState.focusedPanel = viewModel.panelSide
                onPanelTap(viewModel.panelSide)
            }
        )
        .panelFocus(panelSide: viewModel.panelSide) {
            log.debug("Focus lost on << \(viewModel.panelSide)>>; keep selection")
            appState.showFavTreePopup = false
        }
        .onChange(of: appState.focusedPanel) { oldSide, newSide in
            log.debug(
                "[SELECT-FLOW] 6️⃣ FilePanelView.onChange(focusedPanel): \(oldSide) → \(newSide), this panel: <<\(viewModel.panelSide)>>"
            )
            guard oldSide != newSide else {
                log.debug("[SELECT-FLOW] 6️⃣ No actual focus change, skipping")
                return
            }

            if newSide == viewModel.panelSide {
                log.debug("[SELECT-FLOW] 6️⃣ Focus GAINED on <<\(viewModel.panelSide)>>")
            } else {
                log.debug("[SELECT-FLOW] 6️⃣ Focus LOST on <<\(viewModel.panelSide)>>")
            }
            log.debug("[SELECT-FLOW] 6️⃣ DONE")
        }
    }

    // MARK: - Handle double click on file/directory
    private func handleDoubleClick(_ file: CustomFile) {
        log.debug("[DOUBLE-CLICK] handleDoubleClick: \(file.nameStr) isDir=\(file.isDirectory) isSymDir=\(file.isSymbolicDirectory)")
        
        if file.isDirectory || file.isSymbolicDirectory {
            // Enter directory
            let newPath = file.urlValue.path
            log.info("[DOUBLE-CLICK] Entering directory: \(newPath)")
            
            Task { @MainActor in
                appState.updatePath(newPath, for: viewModel.panelSide)
                if viewModel.panelSide == .left {
                    await appState.scanner.setLeftDirectory(pathStr: newPath)
                    await appState.refreshLeftFiles()
                } else {
                    await appState.scanner.setRightDirectory(pathStr: newPath)
                    await appState.refreshRightFiles()
                }
            }
        } else {
            // Open file with default application
            let fileURL = file.urlValue
            log.info("[DOUBLE-CLICK] Opening file: \(fileURL.path)")
            
            let workspace = NSWorkspace.shared
            let configuration = NSWorkspace.OpenConfiguration()
            
            workspace.open(fileURL, configuration: configuration) { app, error in
                if let error = error {
                    log.error("[DOUBLE-CLICK] Failed to open file: \(error.localizedDescription)")
                } else if let app = app {
                    log.info("[DOUBLE-CLICK] File opened with: \(app.localizedName ?? "unknown app")")
                } else {
                    log.warning("[DOUBLE-CLICK] No default application for file type: \(fileURL.pathExtension)")
                }
            }
        }
    }
}

// FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - File panel view for one side (left or right)
struct FilePanelView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel: FilePanelViewModel
    let containerWidth: CGFloat
    @Binding var leftPanelWidth: CGFloat
    let onPanelTap: (PanelSide) -> Void

    // MARK: - Binding to selected file ID
    private var selectedIDBinding: Binding<CustomFile.ID?> {
        Binding<CustomFile.ID?>(
            get: {
                switch viewModel.panelSide {
                case .left: return appState.selectedLeftFile?.id
                case .right: return appState.selectedRightFile?.id
                }
            },
            set: { newValue in
                if newValue == nil {
                    switch viewModel.panelSide {
                    case .left: appState.selectedLeftFile = nil
                    case .right: appState.selectedRightFile = nil
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
        containerWidth: CGFloat,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void,
        appState: AppState,
        onPanelTap: @escaping (PanelSide) -> Void = { _ in }
    ) {
        self._leftPanelWidth = leftPanelWidth
        self.containerWidth = containerWidth
        self._viewModel = State(
            initialValue: FilePanelViewModel(
                panelSide: selectedSide,
                appState: appState,
                fetchFiles: fetchFiles
            )
        )
        self.onPanelTap = onPanelTap
    }

    // MARK: - View
    var body: some View {
        let currentPath = appState.pathURL(for: viewModel.panelSide)
        let files = viewModel.sortedFiles
        
        // Generate content-aware key for file table refresh
        let fileContentKey = makeFileContentKey(files: files, path: currentPath?.path)
        
        return VStack {
            // Breadcrumb navigation
            StableBy(currentPath?.path ?? "") {
                PanelBreadcrumbSection(
                    panelSide: viewModel.panelSide,
                    currentPath: currentPath,
                    onPathChange: { newValue in
                        viewModel.handlePathChange(to: newValue)
                    }
                )
            }
            
            // File table - key includes file content hash for proper refresh
            StableBy(fileContentKey) {
                PanelFileTableSection(
                    files: files,
                    selectedID: selectedIDBinding,
                    panelSide: viewModel.panelSide,
                    onPanelTap: onPanelTap,
                    onSelect: { file in
                        viewModel.select(file)
                    },
                    onDoubleClick: { file in
                        handleDoubleClick(file)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Selection status bar (Total Commander style)
            SelectionStatusBar(panelSide: viewModel.panelSide)
        }
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .background(panelBackground)
        .frame(width: calculatedWidth)
        .animation(nil, value: leftPanelWidth)
        .transaction { tx in
            tx.disablesAnimations = true
            tx.animation = nil
        }
        .background(DesignTokens.panelBg)
        .controlSize(.regular)
        .contentShape(Rectangle())
        .panelFocus(panelSide: viewModel.panelSide) {
            appState.showFavTreePopup = false
        }
    }
    
    // MARK: - Panel background with focus indicator
    private var panelBackground: some View {
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
        .drawingGroup()
    }
    
    // MARK: - Calculated panel width
    private var calculatedWidth: CGFloat? {
        viewModel.panelSide == .left
            ? (leftPanelWidth > 0 ? leftPanelWidth : containerWidth / 2)
            : nil
    }

    // MARK: - Handle double click
    private func handleDoubleClick(_ file: CustomFile) {
        if file.isDirectory || file.isSymbolicDirectory {
            enterDirectory(file)
        } else {
            openFile(file)
        }
    }
    
    // MARK: - Enter directory
    private func enterDirectory(_ file: CustomFile) {
        let resolvedURL = file.urlValue.resolvingSymlinksInPath()
        let newPath = resolvedURL.path
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir), isDir.boolValue else {
            showCannotOpenAlert(file)
            return
        }
        
        Task { @MainActor in
            appState.updatePath(newPath, for: viewModel.panelSide)
            if viewModel.panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: newPath)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: newPath)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
            }
        }
    }
    
    // MARK: - Open file with default app
    private func openFile(_ file: CustomFile) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(file.urlValue, configuration: configuration) { app, error in
            if let error = error {
                log.error("Failed to open file: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Show alert for broken symlink
    private func showCannotOpenAlert(_ file: CustomFile) {
        let alert = NSAlert()
        alert.messageText = "Cannot Open Directory"
        alert.informativeText = "The directory \"\(file.nameStr)\" cannot be opened. It may be a broken symlink or you may not have permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Generate content-aware key for file table refresh
    private func makeFileContentKey(files: [CustomFile], path: String?) -> String {
        var components: [String] = []
        components.append(path ?? "nil")
        components.append(String(files.count))
        
        // Include first few file names to detect content changes
        for file in files.prefix(3) {
            components.append(file.nameStr)
        }
        // Include last file name
        if let last = files.last {
            components.append(last.nameStr)
        }
        
        return components.joined(separator: "|")
    }
}

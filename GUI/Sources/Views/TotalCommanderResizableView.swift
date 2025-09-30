//
//  TotalCommanderResizableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.04.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Note: addKeyPressMonitor() also handles moving row selection with Up/Down arrows.

import AppKit
import SwiftUI

struct TotalCommanderResizableView: View {
    @EnvironmentObject var appState: AppState
    @State private var leftPanelWidth: CGFloat = 0

    // MARK: -
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        TopMenuBarView()
                        Spacer()
                    }
                    buildMainPanels(geometry: geometry)
                    buildDownToolbar()
                }
                .padding(.horizontal, 10)
            }
            .onAppear {
                log.info(#function + " - Initializing app state and panels")
                appState.initialize()
                initializePanelWidth(geometry: geometry)
                appState.forceFocusSelection()
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                if leftPanelWidth > 0 {
                    let maxWidth = newSize.width - 50
                    if leftPanelWidth > maxWidth {
                        leftPanelWidth = maxWidth
                    }
                }
            }
        }
    }

    // MARK: - Fetch Files
    @MainActor
    private func fetchFiles(for panelSide: PanelSide) async {
        log.info("\(#function) [side: \(panelSide)]")
        switch panelSide {
        case .left:
            appState.displayedLeftFiles = await appState.scanner.fileLst
                .getLeftFiles()

        case .right:
            appState.displayedRightFiles = await appState.scanner.fileLst
                .getRightFiles()
        }
    }

    // MARK: - Panels
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        PanelsRowView(leftPanelWidth: $leftPanelWidth, geometry: geometry, fetchFiles: fetchFiles)
    }

    // MARK: -
    private func buildDownToolbar() -> some View {
        log.info(#function)
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
                DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                    log.info("View button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.view(file)
                    } else {
                        log.info("No file selected for View")
                    }
                }
                DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                    if let file = appState.selectedLeftFile {
                        FActions.edit(file)
                    } else {
                        log.info("No file selected for Edit")
                    }
                }
                DownToolbarButtonView(title: "F5 Copy", systemImage: "doc.on.doc") {
                    doCopy()
                }
                DownToolbarButtonView(title: "F6 Move", systemImage: "square.and.arrow.down.on.square") {
                    log.info("Move button tapped")
                }
                DownToolbarButtonView(title: "F7 NewFolder", systemImage: "folder.badge.plus") {
                    log.info("NewFolder button tapped")
                }
                DownToolbarButtonView(title: "F8 Delete", systemImage: "minus.rectangle") {
                    log.info("Delete button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.deleteWithConfirmation(file) {
                            Task {
                                await fetchFiles(for: .left)
                                await fetchFiles(for: .right)
                            }
                        }
                    } else {
                        log.info("No file selected for Delete")
                    }
                }
                DownToolbarButtonView(title: "Settings", systemImage: "gearshape") {
                    log.info("Settings button tapped")
                }
                DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                    log.info("Console button tapped")
                    openConsoleInDirectory("~")
                }
                DownToolbarButtonView(title: "F4 Exit", systemImage: "power") {
                    log.info("F4 Exit button tapped")
                    exitApp()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .cornerRadius(7)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    // MARK: - Toolbar
    private func doCopy() {
        // Determine source file based on focused panel (deprecated API removed)
        let sourceFile = (appState.focusedPanel == .left) ? appState.selectedLeftFile : appState.selectedRightFile

        // Determine target side explicitly to avoid 'opposite' ambiguity
        let targetSide: PanelSide = (appState.focusedPanel == .left) ? .right : .left

        if let file = sourceFile,
            let targetURL = appState.pathURL(for: targetSide)
        {
            FActions.copy(file, to: targetURL)
            Task {
                await appState.refreshFiles()
            }
        } else {
            log.info("No source file selected or target URL missing for Copy")
        }
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        log.info(#function)
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat
            ?? geometry.size.width / 2
    }

    // MARK: -
    private func exitApp() {
        log.info(#function)
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
}
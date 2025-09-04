//
//  FileScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.04.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

struct TotalCommanderResizableView: View {
    @EnvironmentObject var appState: AppState
    @State private var leftPanelWidth: CGFloat = 0

    // MARK: - View Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
            }
            .onAppear {
                log.info(#function + " - Initializing app state and panels")
                appState.initialize()
                initializePanelWidth(geometry: geometry) // Restore divider width from user defaults
                addKeyPressMonitor() // Register keyboard shortcut
            }
            .onChange(of: geometry.size) {
                let newSize = geometry.size
                log.info("Window size changed: \(newSize.width)x\(newSize.height)")
                // пересчитать ширину левой панели, если нужно
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
    private func fetchFiles(for side: PanelSide) async {
        log.info("↪️ \(#function) [side: \(side)]")
        switch side {
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
        log.info(#function)
        return PanelsRowView(
            leftPanelWidth: $leftPanelWidth,
            geometry: geometry,
            fetchFiles: fetchFiles
        )
    }

    private func buildDownToolbar() -> some View {
        log.info(#function)
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
                DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                    log.debug("View button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.view(file)
                    }
                    else {
                        log.debug("No file selected for View")
                    }
                }
                DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                    if let file = appState.selectedLeftFile {
                        FActions.edit(file)
                    }
                    else {
                        log.debug("No file selected for Edit")
                    }
                }
                DownToolbarButtonView(title: "F5 Copy", systemImage: "doc.on.doc") {
                    doCopy()
                }
                DownToolbarButtonView(title: "F6 Move", systemImage: "square.and.arrow.down.on.square") {
                    log.debug("Move button tapped")
                }
                DownToolbarButtonView(title: "F7 NewFolder", systemImage: "folder.badge.plus") {
                    log.debug("NewFolder button tapped")
                }
                DownToolbarButtonView(title: "F8 Delete", systemImage: "minus.rectangle") {
                    log.debug("Delete button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.deleteWithConfirmation(file) {
                            Task {
                                await fetchFiles(for: .left)
                                await fetchFiles(for: .right)
                            }
                        }
                    }
                    else {
                        log.debug("No file selected for Delete")
                    }
                }
                DownToolbarButtonView(title: "Settings", systemImage: "gearshape") {
                    log.debug("Settings button tapped")
                }
                DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                    log.debug("Console button tapped")
                    openConsoleInDirectory("~")
                }
                DownToolbarButtonView(title: "F4 Exit", systemImage: "power") {
                    log.debug("F4 Exit button tapped")
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
    fileprivate func doCopy() {
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
        }
        else {
            log.debug("No source file selected or target URL missing for Copy")
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
    private func addKeyPressMonitor() {
        log.info(#function)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            // Handle Tab key (keyCode 0x30 / 48) — Tab and Shift+Tab toggle focus
            if event.keyCode == 0x30 { // Tab
                if event.modifierFlags.contains(.shift) {
                    log.debug("Shift+Tab pressed → toggle focused panel (reverse)")
                }
                else {
                    log.debug("Tab pressed → toggle focused panel")
                }
                appState.toggleFocus()
                return nil
            }
            return event
        }
    }

    // MARK: -
    private func exitApp() {
        log.info(#function)
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
}

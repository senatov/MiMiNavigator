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
    @State private var isDividerTooltipVisible: Bool = true
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""

    // MARK: - View Body
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

                if isDividerTooltipVisible {
                    PrettyTooltip(text: tooltipText)
                        .position(tooltipPosition)
                        .transition(.opacity)
                        .opacity(0.7)
                        .zIndex(1000)
                }
            }
            .onAppear {
                appState.initialize()
                initializePanelWidth(geometry: geometry)  // Restore divider width from user defaults
                addKeyPressMonitor()  // Register keyboard shortcut
            }
        }
    }

    // MARK: - Fetch Directory Paths
    @MainActor
    private func fetchPaths() async {
        appState.leftPath = appState.model.leftDirectory.path
        appState.rightPath = appState.model.rightDirectory.path
    }

    // MARK: - Fetch Files
    @MainActor
    private func fetchLeftFiles() async {
        appState.displayedLeftFiles = await appState.scanner.fileLst.getLeftFiles()
    }

    // MARK: -
    @MainActor
    private func fetchRightFiles() async {
        appState.displayedRightFiles = await appState.scanner.fileLst.getRightFiles()
    }

    // MARK: - Panels
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: -
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        VStack {
            EditablePathControlWrapper(appState: appState, selectedSide: .left)
                .onChange(of: appState.leftPath) { _, newPath in
                    Task {
                        await appState.scanner.setLeftDirectory(pathStr: newPath)
                        await fetchLeftFiles()
                    }
                }

            List(appState.displayedLeftFiles, id: \.id) { file in
                Text(file.nameStr)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .border(Color.secondary)
        }
        .frame(width: leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)  // Determine left panel width
    }

    // MARK: -
    private func buildRightPanel() -> some View {
        VStack {
            EditablePathControlWrapper(appState: appState, selectedSide: .right)
                .onChange(of: appState.rightPath) { _, newPath in
                    Task {
                        await appState.scanner.setRightDirectory(pathStr: newPath)
                        await fetchRightFiles()
                    }
                }

            List(appState.displayedRightFiles, id: \.id) { file in
                Text(file.nameStr)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .border(Color.secondary)
        }
    }

    // MARK: - Divider
    private func buildDivider(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color(.systemGray))
            .frame(width: 4)
            .opacity(0.2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDividerDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
                        isDividerTooltipVisible = false
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleClickDivider(geometry: geometry)
            }
            .onHover { isHovering in
                DispatchQueue.main.async {
                    isHovering ? NSCursor.resizeLeftRight.push() : NSCursor.pop()
                }
            }
    }

    // MARK: - Toolbar
    private func buildDownToolbar() -> some View {
        HStack(spacing: 18) {
            // MARK: -
            DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                if let file = appState.selectedLeftFile {
                    FActions.view(file)
                } else {
                    log.debug("No file selected for View")
                }
            }
            // MARK: -
            DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                if let file = appState.selectedLeftFile {
                    FActions.edit(file)
                } else {
                    log.debug("No file selected for Edit")
                }
            }
            // MARK: -
            DownToolbarButtonView(title: "F5 Copy", systemImage: "doc.on.doc") {
                let side = appState.focusedSideValue
                if let file = appState.selectedFile(for: side),
                    let targetURL = appState.pathURL(for: side.opposite)
                {
                    FActions.copy(file, to: targetURL)
                    Task {
                        await appState.refreshFiles()
                    }
                }
            }
            // MARK: -
            DownToolbarButtonView(title: "F6 Move", systemImage: "square.and.arrow.down.on.square") {
                log.debug("Move button tapped")
            }
            // MARK: -
            DownToolbarButtonView(title: "F7 NewFolder", systemImage: "folder.badge.plus") {
                log.debug("NewFolder button tapped")
            }
            // MARK: -
            DownToolbarButtonView(title: "F8 Delete", systemImage: "minus.rectangle") {
                if let file = appState.selectedLeftFile {
                    FActions.deleteWithConfirmation(file) {
                        Task {
                            await fetchLeftFiles()
                        }
                    }
                } else {
                    log.debug("No file selected for Delete")
                }
            }
            // MARK: -
            DownToolbarButtonView(title: "Settings", systemImage: "gearshape") {
                log.debug("Settings button tapped")
            }
            // MARK: -
            DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                openConsoleInDirectory("~")
            }
            // MARK: -
            DownToolbarButtonView(title: "F4 Exit", systemImage: "power") {
                exitApp()
            }
        }
        .padding()
        .cornerRadius(7)
    }



    // MARK: -
    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let newWidth = leftPanelWidth + value.translation.width
        let minPanelWidth: CGFloat = 100
        let maxPanelWidth = geometry.size.width - 100

        if newWidth > minPanelWidth && newWidth < maxPanelWidth {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = ToolTipMod.calculateTooltip(
                location: value.location,
                dividerX: newWidth,
                totalWidth: geometry.size.width
            )
            self.tooltipText = tooltipText
            self.tooltipPosition = tooltipPosition
            self.isDividerTooltipVisible = true
        }
    }

    // MARK: -
    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat
            ?? geometry.size.width / 2
    }

    // MARK: -
    private func addKeyPressMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            return event
        }
    }

    // MARK: -
    private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}

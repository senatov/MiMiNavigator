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
    @State private var tooltipText: String = .empty

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
                    if isDividerTooltipVisible {
                        PrettyTooltip(text: tooltipText)
                            .position(tooltipPosition)
                            .transition(.opacity)
                            .opacity(0.7)
                            .zIndex(1000)
                    }
                }
            }
            .onAppear {
                log.info(#function)
                appState.initialize()
                initializePanelWidth(geometry: geometry)  // Restore divider width from user defaults
                addKeyPressMonitor()  // Register keyboard shortcut
            }
            .onChange(of: geometry.size) {
                let newSize = geometry.size
                log.info(
                    "Window size changed: \(newSize.width)x\(newSize.height)"
                )
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
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles
        )
    }

    // MARK: -
    private func buildPanel(for side: PanelSide, geometry: GeometryProxy)
        -> some View
    {
        log.debug(#function + " [side: \(side)]")
        return FilePanelView(
            currSide: side,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles
        )
    }

    // MARK: - Divider
    private func buildDivider(geometry: GeometryProxy) -> some View {
        log.info(#function)
        return ZStack {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 6)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 0)
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.4), lineWidth: 0.5)
                )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    handleDividerDrag(value: value, geometry: geometry)
                }
                .onEnded { _ in
                    UserDefaults.standard.set(
                        leftPanelWidth,
                        forKey: "leftPanelWidth"
                    )
                    isDividerTooltipVisible = false
                }
        )
        .onTapGesture(count: 2) {
            Task { @MainActor in
                handleDoubleClickDivider(geometry: geometry)
            }
        }
        .onHover { isHovering in
            DispatchQueue.main.async {
                isHovering ? NSCursor.resizeLeftRight.push() : NSCursor.pop()
            }
        }
    }

    // MARK: - Toolbar
    private func buildDownToolbar() -> some View {
        log.info(#function)
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
                DownToolbarButtonView(
                    title: "F3 View",
                    systemImage: "eye.circle"
                ) {
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
                DownToolbarButtonView(
                    title: "F5 Copy",
                    systemImage: "doc.on.doc"
                ) {
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
                DownToolbarButtonView(
                    title: "F6 Move",
                    systemImage: "square.and.arrow.down.on.square"
                ) {
                    log.debug("Move button tapped")
                }
                DownToolbarButtonView(
                    title: "F7 NewFolder",
                    systemImage: "folder.badge.plus"
                ) {
                    log.debug("NewFolder button tapped")
                }
                DownToolbarButtonView(
                    title: "F8 Delete",
                    systemImage: "minus.rectangle"
                ) {
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
                DownToolbarButtonView(
                    title: "Settings",
                    systemImage: "gearshape"
                ) {
                    log.debug("Settings button tapped")
                }
                DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                    log.debug("Console button tapped")
                    openConsoleInDirectory("~")
                }
                DownToolbarButtonView(title: "F4 Exit", systemImage: "power") {
                    log.debug("Exit button tapped")
                    exitApp()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .cornerRadius(7)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    // MARK: -
    private func handleDividerDrag(
        value: DragGesture.Value,
        geometry: GeometryProxy
    ) {
        log.info(#function)
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
        log.info(#function)
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
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
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            return event
        }
    }

    // MARK: -
    private func exitApp() {
        log.info(#function)
        NSApplication.shared.terminate(nil)
    }
}

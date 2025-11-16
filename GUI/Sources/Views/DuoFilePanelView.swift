//
//  DuoFilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Note: addKeyPressMonitor() also handles moving row selection with Up/Down arrows.

import AppKit
import SwiftUI

struct DuoFilePanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var keyMonitor: Any? = nil
    private let dividerHitAreaWidth: CGFloat = 24

    // MARK: -
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                TopMenuBarView()
                    .frame(maxWidth: .infinity)
                    .padding(.all, 2)
                PanelsRowView(
                    leftPanelWidth: $leftPanelWidth,
                    geometry: geometry,
                    fetchFiles: fetchFiles(for:)
                )
                .frame(maxWidth: .infinity)
                buildDownToolbar()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, FilePanelStyle.toolbarBottomOffset)

            }
            .onAppear {
                log.debug(#function + " - Initializing app state and panels")
                appState.initialize()
                initializePanelWidth(geometry: geometry)  // Restore divider width from user defaults
                DispatchQueue.main.async {
                    let halfLeft = preciseHalfLeft(totalWidth: geometry.size.width)
                    if abs(leftPanelWidth - halfLeft) > 0.5 {
                        log.debug("DuoFilePanelView.onAppear: re-assert halfLeft=\(Int(halfLeft)) against external override")
                        leftPanelWidth = halfLeft
                    }
                }
                addKeyPressMonitor()  // Register keyboard shortcut
                appState.forceFocusSelection()
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                    log.debug("Removed key monitor on disappear")
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                log.debug(
                    "Window size changed from: \(Int(oldSize.width))x\(Int(oldSize.height)) → \(Int(newSize.width))x\(Int(newSize.height))"
                )
                let minW: CGFloat = 80
                let maxW = max(minW, newSize.width - minW - dividerHitAreaWidth)
                if leftPanelWidth < minW || leftPanelWidth > maxW {
                    let clamped = min(max(leftPanelWidth, minW), maxW)
                    log.debug("Clamp leftPanelWidth → \(Int(clamped)) [min=\(Int(minW)) max=\(Int(maxW))]")
                    leftPanelWidth = clamped
                }
            }
            .onChange(of: leftPanelWidth) { oldValue, newValue in
                UserDefaults.standard.set(newValue, forKey: "leftPanelWidth")
                log.debug("DuoFilePanelView.leftPanelWidth changed → \(Int(oldValue)) → \(Int(newValue)) (persisted)")
            }
        }
    }

    // MARK: - Fetch Files
    @MainActor
    private func fetchFiles(for panelSide: PanelSide) async {
        log.debug("\(#function) [side: <<\(panelSide)>>]")
        switch panelSide {
            case .left:
                appState.displayedLeftFiles = await appState.scanner.fileLst.getLeftFiles()
            case .right:
                appState.displayedRightFiles = await appState.scanner.fileLst.getRightFiles()
        }
    }

    // MARK: -
    private func buildDownToolbar() -> some View {
        log.debug(#function)
        return HStack(spacing: 16) {
            DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                log.debug("View button tapped")
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
                doCopy()
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
                log.debug("Delete button tapped")
                if let file = appState.selectedLeftFile {
                    FActions.deleteWithConfirmation(file) {
                        Task {
                            await fetchFiles(for: .left)
                            await fetchFiles(for: .right)
                        }
                    }
                } else {
                    log.debug("No file selected for Delete")
                }
            }
            DownToolbarButtonView(title: "Settings", systemImage: "gearshape") {
                log.debug("Settings button tapped")
            }
            DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                log.debug("Console button tapped")
                let targetPath = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
                _ = ConsoleCurrPath.open(in: targetPath)
            }
            DownToolbarButtonView(title: "Exit", systemImage: "power") {
                log.debug("F4 Exit button tapped")
                exitApp()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, FilePanelStyle.toolbarHorizontalPadding)
        .padding(.vertical, 10)
        .foregroundStyle(Color.primary.opacity(0.9))
        .saturation(1.2)
        .background(
            RoundedRectangle(cornerRadius: FilePanelStyle.toolbarCornerRadius, style: .continuous)
                .fill(FilePanelStyle.toolbarMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: FilePanelStyle.toolbarCornerRadius, style: .continuous)
                        .fill(FilePanelStyle.toolbarBackgroundTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FilePanelStyle.toolbarCornerRadius, style: .continuous)
                        .strokeBorder(FilePanelStyle.toolbarStrokeOuter, lineWidth: 0.75)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FilePanelStyle.toolbarCornerRadius, style: .continuous)
                        .strokeBorder(FilePanelStyle.toolbarStrokeInner, lineWidth: 0.5)
                        .blendMode(.screen)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FilePanelStyle.toolbarHairlineTop.opacity(0.45))
                        .frame(height: hairlineHeight)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: FilePanelStyle.toolbarCornerRadius + 0.5, style: .continuous)
                        .strokeBorder(FilePanelStyle.toolbarOuterRing, lineWidth: 1.0)
                        .blendMode(.normal)
                )
                .compositingGroup()
                .shadow(
                    color: FilePanelStyle.toolbarShadowColor,
                    radius: FilePanelStyle.toolbarShadowRadius,
                    x: 0,
                    y: FilePanelStyle.toolbarShadowYOffset
                )
        )
        .padding(.horizontal, FilePanelStyle.toolbarHorizontalPadding)
    }

    // MARK: - Toolbar
    private func doCopy() {
        log.debug(#function)
        // Determine the source file based on the focused panel
        let sourceFile = (appState.focusedPanel == .left) ? appState.selectedLeftFile : appState.selectedRightFile
        // Determine the target side explicitly to avoid ambiguity
        let targetSide: PanelSide = (appState.focusedPanel == .left) ? .right : .left
        if let file = sourceFile, let targetURL = appState.pathURL(for: targetSide) {
            FActions.copy(file, to: targetURL)
            Task {
                await appState.refreshFiles()
            }
        } else {
            log.debug("No source file selected or target URL missing for Copy")
        }
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        log.debug(#function)
        let total = geometry.size.width
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        // Calculate exact pixel-aligned center for the divider and convert to left width
        let halfCenter = (total / 2.0 * scale).rounded() / scale
        let halfLeft = halfCenter - dividerHitAreaWidth / 2
        let minW: CGFloat = 80
        let maxW = max(minW, total - minW - dividerHitAreaWidth)
        let saved = (UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat)
        let initial = saved.map { min(max($0, minW), maxW) } ?? halfLeft
        leftPanelWidth = initial
        let savedStr = saved.map { String(Int($0)) } ?? "nil"
        log.debug(
            "Init leftPanelWidth: total=\(Int(total)) scale=\(scale) halfCenter=\(Int(halfCenter)) halfLeft=\(Int(halfLeft)) saved=\(savedStr) → set=\(Int(leftPanelWidth))"
        )
    }

    // MARK: -
    private func addKeyPressMonitor() {
        log.debug(#function)
        // Prevent multiple key monitors from being installed when the view reappears
        if keyMonitor != nil { return }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            // Handle the Tab key (keyCode 0x30 / 48) — Tab and Shift+Tab toggle focus
            if event.keyCode == 0x30 {
                return doPanelToggled(event)
            }
            return event
        }
        self.keyMonitor = monitor
        log.debug("Installed key monitor: \(String(describing: monitor))")
    }

    // MARK: -
    private func doPanelToggled(_ event: NSEvent) -> NSEvent? {
        log.debug(#function)
        appState.toggleFocus()
        appState.forceFocusSelection()
        if event.modifierFlags.contains(.shift) {
            log.debug("Shift+Tab pressed → toggle focused panel (reverse)")
        } else {
            log.debug("Tab pressed → toggle focused panel")
        }
        return nil
    }

    // MARK: -
    private func exitApp() {
        log.debug(#function)
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }

    // MARK: -
    private func preciseHalfLeft(totalWidth: CGFloat) -> CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let halfCenter = (totalWidth / 2.0 * scale).rounded() / scale
        return halfCenter - dividerHitAreaWidth / 2
    }

    // MARK: -
    private var hairlineHeight: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return 1.0 / scale
    }
}

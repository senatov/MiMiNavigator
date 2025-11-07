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
            VStack(spacing: 0) {
                TopMenuBarView()
                    // Panels occupy all remaining vertical space
                PanelsRowView(leftPanelWidth: $leftPanelWidth, geometry: geometry, fetchFiles: fetchFiles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                    // Bottom toolbar fixed at bottom
                HStack {
                    buildDownToolbar()
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        log.debug("\(#function) [side: \(panelSide)]")
        switch panelSide {
            case .left:
                appState.displayedLeftFiles = await appState.scanner.fileLst.getLeftFiles()
            case .right:
                appState.displayedRightFiles = await appState.scanner.fileLst.getRightFiles()
        }
    }
    
        // MARK: -
    private func buildDownToolbar() -> some View {
        return VStack(spacing: 0) {
            HStack(spacing: 16) {
                DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                    log.debug("View button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.view(file)
                    } else {
                        log.debug("No file selected for View")
                    }
                }
                DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                    if let file = appState.selectedLeftFile {
                        FActions.edit(file)
                    } else {
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
                    } else {
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
                DownToolbarButtonView(title: "Exit", systemImage: "power") {
                    log.debug("F4 Exit button tapped")
                    exitApp()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                // Liquid glass container with very soft elevation
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                    )
                    .overlay(
                        // Inner subtle highlight
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5)
                            .blendMode(.screen)
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
    }
    
        // MARK: - Toolbar
    private func doCopy() {
            // Determine source file based on focused panel (deprecated API removed)
        let sourceFile = (appState.focusedPanel == .left) ? appState.selectedLeftFile : appState.selectedRightFile
            // Determine target side explicitly to avoid 'opposite' ambiguity
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
            // Exact pixel-aligned center for divider, convert to left width
        let halfCenter = (total / 2.0 * scale).rounded() / scale
        let halfLeft = halfCenter - dividerHitAreaWidth / 2
        let minW: CGFloat = 80
        let maxW = max(minW, total - minW - dividerHitAreaWidth)
        let saved = (UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat)
        let initial = saved.map { min(max($0, minW), maxW) } ?? halfLeft
        leftPanelWidth = initial
        log.debug(
            "Init leftPanelWidth: total=\(Int(total)) scale=\(scale) halfCenter=\(Int(halfCenter)) halfLeft=\(Int(halfLeft)) saved=\(saved.map{Int($0)}?.description ?? "nil") → set=\(Int(leftPanelWidth))"
        )
    }
    
        // MARK: -
    private func addKeyPressMonitor() {
        log.debug(#function)
            // Avoid installing multiple monitors when the view re-appears
        if keyMonitor != nil { return }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                exitApp()
                return nil
            }
                // Handle Tab key (keyCode 0x30 / 48) — Tab and Shift+Tab toggle focus
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
    
    private func preciseHalfLeft(totalWidth: CGFloat) -> CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let halfCenter = (totalWidth / 2.0 * scale).rounded() / scale
        return halfCenter - dividerHitAreaWidth / 2
    }
}

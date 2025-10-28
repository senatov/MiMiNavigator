//
//  DownPanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Note: addKeyPressMonitor() also handles moving row selection with Up/Down arrows.

import AppKit
import SwiftUI

struct DownPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var keyMonitor: Any? = nil

    // MARK: -
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    VStack(spacing: 0) {
                        HStack {
                            TopMenuBarView()
                        }

                        // Panels occupy all remaining vertical space
                        PanelsRowView(leftPanelWidth: $leftPanelWidth, geometry: geometry, fetchFiles: fetchFiles)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)

                        Spacer(minLength: 0)

                        // Bottom toolbar fixed at bottom
                        buildDownToolbar()
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                log.debug(#function + " - Initializing app state and panels")
                appState.initialize()
                initializePanelWidth(geometry: geometry)  // Restore divider width from user defaults
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
                log.debug("Window size changed from: \(oldSize.width)x\(oldSize.height) → \(newSize.width)x\(newSize.height)")
                // Recalculate left panel width if needed
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
        log.debug("\(#function) [side:<<\(panelSide)]>>")
        switch panelSide {
            case .left:
                appState.displayedLeftFiles = await appState.scanner.fileLst
                    .getLeftFiles()

            case .right:
                appState.displayedRightFiles = await appState.scanner.fileLst
                    .getRightFiles()
        }
    }

    // MARK: -
    private func buildDownToolbar() -> some View {
        log.debug(#function)
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
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
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.07)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Subtle bevel highlight (keeps main colors intact)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    // Ambient soft shadow close to the surface
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    // Main drop shadow per macOS 26.1 liquid glass
                    .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 12)
                    // Optional subtle top highlight glow
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.6)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.07)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
            log.debug("No source file selected or target URL missing for Copy")
        }
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        log.debug(#function)
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat
            ?? geometry.size.width / 2
    }

    // MARK: -
    private func addKeyPressMonitor() {
        log.debug(#function)
        // Avoid installing multiple monitors when the view re-appears
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
        log.debug("Installed key monitor: \(String(describing: keyMonitor))")
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
}

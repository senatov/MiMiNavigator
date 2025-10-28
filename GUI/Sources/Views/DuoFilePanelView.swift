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
    var downPanelView: DownPanelView = DownPanelView()

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
    func fetchFiles(for panelSide: PanelSide) async {
        log.debug("\(#function) [side:<<\(panelSide)]>>")
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
        return downPanelView
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        log.debug(#function)
        leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }

    // MARK: -
    private func addKeyPressMonitor() {
        log.debug(#function)
        // Avoid installing multiple monitors when the view re-appears
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                downPanelView.exitApp()
                return nil
            }
            // Handle Tab key (keyCode 0x30 / 48) — Tab and Shift+Tab toggle focus
            if event.keyCode == 0x30 {
                return downPanelView.doPanelToggled(event)
            }
            return event
        }
        log.debug("Installed key monitor: \(String(describing: keyMonitor))")
    }
}

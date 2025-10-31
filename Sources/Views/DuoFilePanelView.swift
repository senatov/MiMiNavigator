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
    @State private var keyMonitor: Any? = nil
    var downPanelView: DownPanelView = DownPanelView()
    
        // MARK: - Tooltip state for divider drag
    @State private var showTooltip = false
    @State private var tooltipText = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var containerSize: CGSize = .zero
    
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
                        PanelsRowView(fetchFiles: fetchFiles)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                            // Bottom toolbar fixed at bottom
                        buildDownToolbar()
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped(antialiased: true)
                    .contentShape(Rectangle())
                    .transaction { $0.disablesAnimations = true }
                    .animation(nil, value: appState.focusedPanel)
                    .overlay(
                        GeometryReader { gp in
                            Color.clear
                                .onChange(of: gp.size) { oldSize, newSize in
                                    log.debug(
                                        "DuoFilePanelView size: \(Int(oldSize.width))x\(Int(oldSize.height)) → \(Int(newSize.width))x\(Int(newSize.height))"
                                    )
                                }
                        }
                            .allowsHitTesting(false)
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                if showTooltip {
                    DividerTooltip(text: tooltipText)
                        .position(tooltipPosition)
                        .transition(.opacity)
                }
            }
            .onAppear {
                log.debug(#function + " - Initializing app state and panels")
                appState.initialize()
                addKeyPressMonitor()  // Register keyboard shortcut
                appState.forceFocusSelection()
                containerSize = geometry.size
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                    log.debug("Removed key monitor on disappear")
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                containerSize = newSize
                log.debug("Window size changed from: \(oldSize.width)x\(oldSize.height) → \(newSize.width)x\(newSize.height)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .dividerDragChanged)) { note in
                guard let userInfo = note.userInfo,
                      let dividerX = userInfo["dividerX"] as? CGFloat,
                      let pointer = userInfo["pointer"] as? CGPoint else { return }
                let text = ToolTipMod.buildText(dividerX: dividerX, totalWidth: containerSize.width)
                let pos  = ToolTipMod.place(reference: pointer, dividerX: dividerX, containerSize: containerSize)
                tooltipText = text
                tooltipPosition = pos
                if !showTooltip { showTooltip = true }
                log.debug("tooltip → \(text) @ \(pos)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .dividerDragEnded)) { _ in
                showTooltip = false
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
    private func addKeyPressMonitor() {
        log.debug(#function)
            // Avoid installing multiple monitors when the view re-appears
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                downPanelView.exitApp()
                return nil
            }
                // Handle Tab key (keyCode 0x30 / 48) — toggle panel focus only when file panels own focus
            if event.keyCode == 0x30 {
                    // Ignore auto-repeat to avoid rapid re-entrancy
                if event.isARepeat { return event }
                    // If a text input control owns firstResponder, don't intercept Tab
                if let first = NSApp.keyWindow?.firstResponder {
                    if first is NSTextView || first is NSTextField || first is NSSearchField {
                        return event
                    }
                }
                    // Defer state mutation to the next runloop to avoid layout during monitor callback
                DispatchQueue.main.async {
                    appState.toggleFocus()
                }
                    // Consume the event only if we handled it here
                return nil
            }
            return event
        }
        log.debug("Installed key monitor: \(String(describing: keyMonitor))")
    }
}

extension Notification.Name {
    static let dividerDragChanged = Notification.Name("DividerDragChanged")
    static let dividerDragEnded   = Notification.Name("DividerDragEnded")
}

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
    @State private var keyMonitorGlobal: Any? = nil
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
                if let global = keyMonitorGlobal {
                    NSEvent.removeMonitor(global)
                    keyMonitorGlobal = nil
                    log.debug("Removed global key monitor on disappear")
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                containerSize = newSize
                log.debug("Window size changed from: \(oldSize.width)x\(oldSize.height) → \(newSize.width)x\(newSize.height)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .dividerDragChanged)) { note in
                guard let userInfo = note.userInfo,
                      let dividerX = userInfo["dividerX"] as? CGFloat,
                      let pointer = userInfo["pointer"] as? CGPoint else {
                    log.error("dividerDragChanged: missing userInfo or keys")
                    return
                }
                log.debug("dividerDragChanged recv: dividerX=\(Int(dividerX)) pointer=\(Int(pointer.x));\(Int(pointer.y)) container=\(Int(containerSize.width))x\(Int(containerSize.height))")
                
                let text = ToolTipMod.buildText(dividerX: dividerX, totalWidth: containerSize.width)
                let pos  = ToolTipMod.place(reference: pointer, dividerX: dividerX, containerSize: containerSize)
                
                tooltipText = text
                tooltipPosition = pos
                if !showTooltip {
                    showTooltip = true
                    log.debug("tooltip show → true")
                }
                log.debug("tooltip computed: \(text) @ \(pos)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .dividerDragEnded)) { _ in
                log.debug("dividerDragEnded recv: hiding tooltip (was: \(showTooltip)) @ \(tooltipPosition)")
                showTooltip = false
            }
            .onChange(of: showTooltip) { oldValue, newValue in
                log.debug("showTooltip changed: \(oldValue) → \(newValue) text='\(tooltipText)' pos=\(tooltipPosition)")
            }
        }
    }
    
        // MARK: - Keyboard handling (Tab)
    private func handleTab(_ event: NSEvent, source: String) -> Bool {
            // Accept TAB by keyCode or by charactersIgnoringModifiers
        let isTabKey = (event.keyCode == 0x30) || (event.charactersIgnoringModifiers == "\t")
        guard isTabKey else { return false }
        
            // Ignore auto-repeat to avoid re-entrancy
        if event.isARepeat {
            log.debug("Tab (")
            log.debug("Tab (\(source)) ignored: isARepeat=true")
            return false
        }
            // Do not intercept when a text input owns focus
        if let first = NSApp.keyWindow?.firstResponder,
           (first is NSTextView) || (first is NSTextField) || (first is NSSearchField) {
            log.debug("Tab (\(source)) ignored: firstResponder is text input → \(type(of: first))")
            return false
        }
            // All clear → toggle on next runloop tick
        log.debug("Tab (\(source)) → calling toggleFocus()")
        DispatchQueue.main.async { appState.toggleFocus() }
        return true
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
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // Option+Help to exit
                if event.modifierFlags.contains(.option), event.keyCode == 0x76 {
                    downPanelView.exitApp()
                    return nil
                }
                    // Handle Tab locally; consume if handled
                if handleTab(event, source: "local") { return nil }
                return event
            }
            log.debug("Installed local key monitor: \(String(describing: keyMonitor))")
        }
        if keyMonitorGlobal == nil {
            keyMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                _ = handleTab(event, source: "global")
            }
            log.debug("Installed global key monitor: \(String(describing: keyMonitorGlobal))")
        }
    }
}

extension Notification.Name {
    static let dividerDragChanged = Notification.Name("DividerDragChanged")
    static let dividerDragEnded   = Notification.Name("DividerDragEnded")
}

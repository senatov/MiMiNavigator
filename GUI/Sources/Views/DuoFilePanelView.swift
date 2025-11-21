    //
    // DuoFilePanelView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 26.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI

struct DuoFilePanelView: View {
        // MARK: - Environment & State
    @EnvironmentObject private var appState: AppState
    @State private var leftPanelWidth: CGFloat = 0
    @State private var keyMonitor: Any?
    
        // MARK: - Constants
    private enum Layout {
        static let dividerHitAreaWidth: CGFloat = 24
        static let topMenuPadding: CGFloat = 8
        static let toolbarHorizontalPadding: CGFloat = 16
        static let toolbarVerticalPadding: CGFloat = 12
        static let toolbarCornerRadius: CGFloat = 10
        static let toolbarOuterPadding: CGFloat = 8
        static let toolbarBottomPadding: CGFloat = 8
        static let toolbarButtonSpacing: CGFloat = 12
        static let minPanelWidth: CGFloat = 80
    }
    
        // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            topMenuBar
            filePanels
            bottomToolbar
        }
        .onAppear {
            appState.initialize()
            initializePanelWidth()
            registerKeyboardShortcuts()
            appState.forceFocusSelection()
        }
        .onDisappear {
            unregisterKeyboardShortcuts()
        }
        .onChange(of: leftPanelWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "leftPanelWidth")
        }
    }
}

    // MARK: - View Components
extension DuoFilePanelView {
    private var topMenuBar: some View {
        TopMenuBarView()
            .frame(maxWidth: .infinity)
            .padding(Layout.topMenuPadding)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var filePanels: some View {
        GeometryReader { geometry in
            PanelsRowView(
                leftPanelWidth: $leftPanelWidth,
                geometry: geometry,
                fetchFiles: fetchFiles
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var bottomToolbar: some View {
        HStack(spacing: Layout.toolbarButtonSpacing) {
            makeButton(title: "F3 View", icon: "eye.circle", action: performView)
            makeButton(title: "F4 Edit", icon: "pencil", action: performEdit)
            makeButton(title: "F5 Copy", icon: "doc.on.doc", action: performCopy)
            makeButton(title: "F6 Move", icon: "square.and.arrow.down.on.square", action: performMove)
            makeButton(title: "F7 NewFolder", icon: "folder.badge.plus", action: performNewFolder)
            makeButton(title: "F8 Delete", icon: "minus.rectangle", action: performDelete)
            makeButton(title: "Settings", icon: "gearshape", action: performSettings)
            makeButton(title: "Console", icon: "terminal", action: performConsole)
            makeButton(title: "Exit", icon: "power", action: performExit)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.toolbarHorizontalPadding)
        .padding(.vertical, Layout.toolbarVerticalPadding)
        .background(toolbarBackgroundView)
        .padding(.horizontal, Layout.toolbarOuterPadding)
        .padding(.bottom, Layout.toolbarBottomPadding)
    }
    
    private var toolbarBackgroundView: some View {
        ZStack {
            baseMaterial
            overlayTint
            borderStroke
            topHighlight
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
    
    private var baseMaterial: some View {
        RoundedRectangle(cornerRadius: Layout.toolbarCornerRadius, style: .continuous)
            .fill(.regularMaterial)
    }
    
    private var overlayTint: some View {
        RoundedRectangle(cornerRadius: Layout.toolbarCornerRadius, style: .continuous)
            .fill(.white.opacity(0.05))
    }
    
    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: Layout.toolbarCornerRadius, style: .continuous)
            .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
    }
    
    private var topHighlight: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
            Spacer(minLength: 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: Layout.toolbarCornerRadius, style: .continuous))
    }
    
    private func makeButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        DownToolbarButtonView(
            title: title,
            systemImage: icon,
            action: action
        )
    }
}

    // MARK: - File Operations
extension DuoFilePanelView {
    @MainActor
    private func fetchFiles(for side: PanelSide) async {
        switch side {
            case .left:
                appState.displayedLeftFiles = await appState.scanner.fileLst.getLeftFiles()
            case .right:
                appState.displayedRightFiles = await appState.scanner.fileLst.getRightFiles()
        }
    }
    
    private func performView() {
        guard let file = appState.selectedLeftFile else { return }
        FActions.view(file)
    }
    
    private func performEdit() {
        guard let file = appState.selectedLeftFile else { return }
        FActions.edit(file)
    }
    
    private func performCopy() {
        guard let source = currentSelectedFile,
              let destination = targetPanelURL else { return }
        
        FActions.copy(source, to: destination)
        Task { await appState.refreshFiles() }
    }
    
    private func performMove() {
            // TODO: Implement move
    }
    
    private func performNewFolder() {
            // TODO: Implement new folder
    }
    
    private func performDelete() {
        guard let file = appState.selectedLeftFile else { return }
        
        FActions.deleteWithConfirmation(file) {
            Task {
                await fetchFiles(for: .left)
                await fetchFiles(for: .right)
            }
        }
    }
    
    private func performSettings() {
            // TODO: Implement settings
    }
    
    private func performConsole() {
        let path = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
        _ = ConsoleCurrPath.open(in: path)
    }
    
    private func performExit() {
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
}

    // MARK: - Computed Properties
extension DuoFilePanelView {
    private var currentSelectedFile: CustomFile? {
        appState.focusedPanel == .left ?
        appState.selectedLeftFile :
        appState.selectedRightFile
    }
    
    private var targetPanelURL: URL? {
        let targetSide: PanelSide = appState.focusedPanel == .left ? .right : .left
        return appState.pathURL(for: targetSide)
    }
}

    // MARK: - Panel Width Management
extension DuoFilePanelView {
    private func initializePanelWidth() {
        guard let screen = NSScreen.main else { return }
        
        let screenWidth = screen.frame.width
        let scale = screen.backingScaleFactor
        
        let centerX = (screenWidth / 2.0 * scale).rounded() / scale
        let defaultLeftWidth = centerX - Layout.dividerHitAreaWidth / 2
        
        let maxWidth = screenWidth - Layout.minPanelWidth - Layout.dividerHitAreaWidth
        let constrainedWidth = min(max(defaultLeftWidth, Layout.minPanelWidth), maxWidth)
        
        if let savedWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat {
            leftPanelWidth = min(max(savedWidth, Layout.minPanelWidth), maxWidth)
        } else {
            leftPanelWidth = constrainedWidth
        }
    }
}

    // MARK: - Keyboard Shortcuts
extension DuoFilePanelView {
    private func registerKeyboardShortcuts() {
        guard keyMonitor == nil else { return }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            self.handleKeyEvent(event, appState: appState)
        }
    }
    
    private func unregisterKeyboardShortcuts() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent, appState: AppState?) -> NSEvent? {
        if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
            appState?.saveBeforeExit()
            NSApplication.shared.terminate(nil)
            return nil
        }
        
        if event.keyCode == 0x30 {
            appState?.toggleFocus()
            appState?.forceFocusSelection()
            return nil
        }
        
        return event
    }
}

// MultiRenameCoordinator.swift
// MiMiNavigator

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Multi Rename Coordinator

@MainActor
@Observable
final class MultiRenameCoordinator {
    static let shared = MultiRenameCoordinator()
    private(set) var isVisible = false
    private var window: NSWindow?
    private let viewModel = MultiRenameViewModel()
    private let frameAutosaveName = "MiMiNavigator.MultiRenameWindow"
    private init() {}

    func toggle(panel: FavPanelSide, appState: AppState) {
        if isVisible {
            close()
            return
        }
        open(panel: panel, appState: appState)
    }

    func open(panel: FavPanelSide, appState: AppState) {
        let allFiles = appState.displayedFiles(for: panel).filter { !$0.isParentEntry }
        let selectedFiles = appState.filesForOperation(on: panel).filter { !$0.isParentEntry }
        let allSources = allFiles.map { MultiRenameSource(url: $0.urlValue, isDirectory: $0.isDirectory) }
        let selectedSources = selectedFiles.map { MultiRenameSource(url: $0.urlValue, isDirectory: $0.isDirectory) }
        viewModel.configure(allSources: allSources, selectedSources: selectedSources, panel: panel, appState: appState)
        if let window {
            window.makeKeyAndOrderFront(nil)
            window.recalculateKeyViewLoop()
            isVisible = true
            log.info("[MultiRename] window reopened with \(allSources.count) items")
            return
        }
        let hostingView = NSHostingView(rootView: MultiRenameWindowContent(viewModel: viewModel).frame(minWidth: 680, minHeight: 520))
        let panelWindow = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow], backing: .buffered, defer: false)
        panelWindow.contentView = hostingView
        panelWindow.isReleasedWhenClosed = false
        panelWindow.minSize = NSSize(width: 680, height: 520)
        panelWindow.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: panelWindow, systemImage: "text.line.2.summary", title: "Multi-Rename Tool")
        panelWindow.toolbarStyle = .unified
        panelWindow.animationBehavior = .utilityWindow
        panelWindow.hidesOnDeactivate = false
        panelWindow.level = .normal
        panelWindow.tabbingMode = .disallowed
        panelWindow.autorecalculatesKeyViewLoop = true
        if !panelWindow.setFrameUsingName(frameAutosaveName) { panelWindow.center() }
        panelWindow.setFrameAutosaveName(frameAutosaveName)
        panelWindow.delegate = MultiRenameWindowDelegate.shared
        panelWindow.makeKeyAndOrderFront(nil)
        panelWindow.recalculateKeyViewLoop()
        window = panelWindow
        isVisible = true
        log.info("[MultiRename] window opened with \(allSources.count) items")
    }

    func close() {
        window?.close()
        isVisible = false
    }

    func bringToFront() {
        guard isVisible else { return }
        window?.orderFront(nil)
    }

    func windowDidClose() {
        isVisible = false
    }
}

// MARK: - Multi Rename Window Delegate

private final class MultiRenameWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = MultiRenameWindowDelegate()
    func windowWillClose(_: Notification) {
        Task { @MainActor in MultiRenameCoordinator.shared.windowDidClose() }
    }
}
